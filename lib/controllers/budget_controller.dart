import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/firestore_budget_service.dart';
import '../services/notification_service.dart';
import '../services/threshold_monitor_service.dart';
import '../utils/app_logger.dart';

import 'package:firebase_auth/firebase_auth.dart';

/// Controller for managing budget target with real-time IoT device streaming
class BudgetController with ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreBudgetService _firestoreService = FirestoreBudgetService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<DatabaseEvent>? _rtdbSub;
  Timer? _remainingTimer;

  // Track pending remaining budget value to ensure it's saved even when throttled
  double? _pendingRemainingBudget;

  // Throttling for immediate RTDB updates (max once per 100ms for real-time sync)
  DateTime? _lastRtdbUpdateTime;
  static const Duration _rtdbUpdateThrottle = Duration(milliseconds: 100);

  // Budget settings
  double totalBudget = 0;
  double ratePerKwh = 12.50; // default
  int thresholdPercentage = 80;
  bool alertEnabled = true;
  double remainingBudget = 0;

  // Aggregated from devices
  double totalKwhUsed = 0;

  // Alert tracking metadata
  DateTime? lastAlertDismissedAt;
  String? lastAlertDismissedType;
  DateTime? lastAlertGeneratedAt;
  String? lastAlertGeneratedType;
  DateTime? snoozedUntil;

  // Baseline kWh used when budget was set/edited (for resetting consumed budget)
  double baselineKwhUsed = 0.0;

  bool _isInitialized = false;
  bool _notificationSentForToday = false;
  int? _lastThresholdThatTriggered;
  bool _disposed = false;

  /// Get current user ID
  String get _userId => _auth.currentUser?.uid ?? '';

  /// Get database reference for appliances
  DatabaseReference get _rtdbRef => _database.ref('users/$_userId/appliances');

  BudgetController();

  /// Initialize controller by loading Firestore settings and starting RTDB listener
  Future<void> init() async {
    if (_isInitialized) return;

    // Check if user is authenticated
    if (_userId.isEmpty) {
      AppLogger.w(
        '[BudgetController] User not authenticated, skipping initialization',
      );
      return;
    }

    try {
      // Load Firestore settings first
      final budgetData = await _firestoreService.getBudgetTarget();
      if (budgetData != null) {
        totalBudget = budgetData['totalBudget'] ?? 0.0;
        ratePerKwh = budgetData['ratePerKwh'] ?? 12.50;
        thresholdPercentage =
            (budgetData['thresholdPercentage'] ?? 80.0).toInt();
        alertEnabled = budgetData['alertEnabled'] ?? true;
        remainingBudget = budgetData['remainingBudget'] ?? totalBudget;
        _pendingRemainingBudget = remainingBudget;
        baselineKwhUsed = budgetData['baselineKwhUsed'] ?? 0.0;
        lastAlertDismissedAt = budgetData['lastAlertDismissedAt'] as DateTime?;
        lastAlertDismissedType =
            budgetData['lastAlertDismissedType'] as String?;
        lastAlertGeneratedAt = budgetData['lastAlertGeneratedAt'] as DateTime?;
        lastAlertGeneratedType =
            budgetData['lastAlertGeneratedType'] as String?;
        snoozedUntil = budgetData['snoozedUntil'] as DateTime?;
      }

      // Load current power rate from Firestore
      await _loadCurrentPowerRate();

      // Start listening to Realtime Database for appliance updates
      _startRealtimeListener();

      // Start periodic remainingBudget sync to Realtime DB every 1 second
      _remainingTimer?.cancel();
      _remainingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final remainingRef = FirebaseDatabase.instance.ref(
            'users/$_userId/target_threshold/remaining_budget',
          );
          await remainingRef.set(remainingBudget);
        } catch (_) {
          // ignore transient errors
        }
      });

      // Ensure background monitoring keeps running even when app is closed.
      await ThresholdMonitorService.instance.registerBackgroundTask();
      await ThresholdMonitorService.instance.runImmediateCheck();

      _isInitialized = true;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('[BudgetController] Error initializing: $e');
    }
  }

  /// Load current power rate from Firestore admin_settings/system_config/powerRate
  Future<void> _loadCurrentPowerRate() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('admin_settings')
              .doc('system_config')
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data['powerRate'] != null) {
          ratePerKwh = (data['powerRate'] as num).toDouble();
          AppLogger.i(
            '[BudgetController] Loaded power rate from Firestore: $ratePerKwh',
          );
        }
      }
    } catch (e) {
      AppLogger.w('[BudgetController] Error loading power rate: $e');
      // Keep default ratePerKwh if error occurs
    }
  }

  /// Safe notify listeners that checks if disposed
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Start listening to Realtime Database for device data changes
  void _startRealtimeListener() {
    _rtdbSub?.cancel(); // Cancel existing subscription if any

    _rtdbSub = _rtdbRef.onValue.listen(
      (DatabaseEvent event) {
        _handleRealtimeUpdate(event);
      },
      onError: (error) {
        debugPrint('[BudgetController] RTDB error: $error');
      },
    );
  }

  /// Handle real-time database update from appliances
  void _handleRealtimeUpdate(DatabaseEvent event) {
    try {
      final snapshot = event.snapshot;

      if (snapshot.value == null) {
        totalKwhUsed = 0;
      } else {
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        double sumKwh = 0;

        // Sum all appliances' cumulative kwh values
        map.forEach((applianceId, applianceData) {
          final appliance = Map<String, dynamic>.from(applianceData);
          // Appliances use 'kwh' (lowercase) for cumulative usage
          final kwh = (appliance['kwh'] ?? 0.0).toDouble();
          sumKwh += kwh;
        });

        totalKwhUsed = sumKwh;
        AppLogger.d('[BudgetController] Total kWh from appliances: $sumKwh');
      }

      _recalculateAndMaybeNotify();
    } catch (e) {
      debugPrint('[BudgetController] Error handling RTDB update: $e');
      AppLogger.e('[BudgetController] Error handling RTDB update: $e');
    }
  }

  /// Recalculate remaining budget and trigger notifications if threshold reached
  Future<void> _recalculateAndMaybeNotify() async {
    if (totalBudget == 0) {
      _safeNotifyListeners();
      return; // No budget set yet
    }

    // Calculate consumed cost from all appliances' cumulative kwh * current power rate
    // Subtract baseline to reset consumed budget when budget is edited
    final consumedKwh = (totalKwhUsed - baselineKwhUsed).clamp(
      0.0,
      double.infinity,
    );
    final totalConsumedCost = consumedKwh * ratePerKwh;
    remainingBudget = (totalBudget - totalConsumedCost).clamp(
      0.0,
      double.infinity,
    );

    // Always update pending value to track latest remaining budget
    _pendingRemainingBudget = remainingBudget;

    AppLogger.d(
      '[BudgetController] Recalculated: Total kWh=$totalKwhUsed, Baseline kWh=$baselineKwhUsed, Consumed kWh=$consumedKwh, Rate=$ratePerKwh, Consumed Cost=₱$totalConsumedCost, Remaining=₱$remainingBudget',
    );

    // Update RTDB remaining_budget immediately (with throttling) for real-time sync
    // Remaining budget is ONLY stored in Realtime Database, not Firestore
    _updateRtdbRemainingBudgetImmediate();

    _safeNotifyListeners();

    // Check if threshold reached and send notification
    if (alertEnabled && totalBudget > 0) {
      // Use consumedCostValue to get the correct consumed cost
      final usedPercent = (consumedCostValue / totalBudget) * 100;

      AppLogger.d(
        '[BudgetController] Checking threshold: usedPercent=$usedPercent%, threshold=$thresholdPercentage%, alertEnabled=$alertEnabled, notificationSentForToday=$_notificationSentForToday',
      );

      // Check if threshold has changed - if so, reset notification flag to allow new notification
      if (_lastThresholdThatTriggered != null &&
          _lastThresholdThatTriggered != thresholdPercentage) {
        AppLogger.i(
          '[BudgetController] Threshold changed from $_lastThresholdThatTriggered% to $thresholdPercentage% - resetting notification flag',
        );
        _notificationSentForToday = false;
        // Reset proceed state when threshold changes
        _notificationService.resetProceedState();
      }

      if (usedPercent >= thresholdPercentage) {
        AppLogger.i(
          '[BudgetController] Threshold reached! usedPercent=$usedPercent% >= threshold=$thresholdPercentage%',
        );

        // Check if proceed is active - if so, continue sending notifications
        final proceedActive = await _notificationService.isProceedActive();
        AppLogger.d('[BudgetController] Proceed active: $proceedActive');

        if (proceedActive) {
          // Proceed is active - send notification regardless of _notificationSentForToday flag
          // This allows continuous notifications until dismissed
          // Bypass daily check to allow multiple notifications
          AppLogger.i(
            '[BudgetController] Sending notification (proceed active) - bypassing daily check',
          );
          _notificationService.sendBudgetThresholdNotification(
            consumedCost: totalConsumedCost,
            remainingBudget: remainingBudget,
            totalBudget: totalBudget,
            thresholdPercentage: thresholdPercentage.toDouble(),
            bypassDailyCheck: true,
          );
          AppLogger.i(
            '[BudgetController] Notification sent (proceed active) for threshold $thresholdPercentage%',
          );
        } else if (!_notificationSentForToday) {
          // Normal flow - send notification only if not sent today
          AppLogger.i(
            '[BudgetController] Sending notification (first time today)',
          );
          _notificationService.sendBudgetThresholdNotification(
            consumedCost: totalConsumedCost,
            remainingBudget: remainingBudget,
            totalBudget: totalBudget,
            thresholdPercentage: thresholdPercentage.toDouble(),
          );
          _notificationSentForToday = true;
          _lastThresholdThatTriggered = thresholdPercentage;
          AppLogger.i(
            '[BudgetController] Notification sent for threshold $thresholdPercentage%',
          );
        } else {
          AppLogger.d(
            '[BudgetController] Notification already sent today - skipping (use Proceed to continue)',
          );
        }
      } else {
        AppLogger.d(
          '[BudgetController] Threshold not reached: usedPercent=$usedPercent% < threshold=$thresholdPercentage%',
        );
      }
    } else {
      if (!alertEnabled) {
        AppLogger.d(
          '[BudgetController] Alerts disabled - skipping notification check',
        );
      }
      if (totalBudget == 0) {
        AppLogger.d(
          '[BudgetController] No budget set - skipping notification check',
        );
      }
    }
  }

  /// Update RTDB remaining_budget immediately (with throttling) for real-time sync
  /// Remaining budget is ONLY stored in Realtime Database, not Firestore
  void _updateRtdbRemainingBudgetImmediate() {
    // Always update pending value to track latest remaining budget
    _pendingRemainingBudget = remainingBudget;

    final now = DateTime.now();

    // Throttle to prevent excessive writes (max once per 100ms)
    if (_lastRtdbUpdateTime != null) {
      final timeSinceLastUpdate = now.difference(_lastRtdbUpdateTime!);
      if (timeSinceLastUpdate < _rtdbUpdateThrottle) {
        return; // Skip this write, but pending value is already updated
      }
    }

    _lastRtdbUpdateTime = now;

    // Update RTDB immediately for real-time sync
    try {
      final remainingRef = FirebaseDatabase.instance.ref(
        'users/$_userId/target_threshold/remaining_budget',
      );
      remainingRef
          .set(remainingBudget)
          .then((_) {
            _pendingRemainingBudget =
                null; // Clear pending after successful save
          })
          .catchError((error) {
            AppLogger.w(
              '[BudgetController] Error updating RTDB remaining_budget immediately: $error',
            );
          });
    } catch (e) {
      AppLogger.w(
        '[BudgetController] Exception updating RTDB remaining_budget: $e',
      );
    }
  }

  /// Force save pending remaining budget immediately to RTDB (used on dispose)
  /// Remaining budget is ONLY stored in Realtime Database, not Firestore
  Future<void> _savePendingRemainingBudget() async {
    // Always save the current remainingBudget value to RTDB if there's a pending change or budget is set
    if (_pendingRemainingBudget != null ||
        (remainingBudget != 0 || totalBudget > 0)) {
      try {
        final remainingRef = FirebaseDatabase.instance.ref(
          'users/$_userId/target_threshold/remaining_budget',
        );
        await remainingRef.set(remainingBudget);
        AppLogger.d(
          '[BudgetController] Saved remaining budget to RTDB on dispose: ₱$remainingBudget',
        );
        _pendingRemainingBudget = null;
      } catch (e) {
        AppLogger.e(
          '[BudgetController] Error saving remaining budget to RTDB on dispose: $e',
        );
      }
    }
  }

  /// Save budget settings to Firestore
  Future<bool> saveSettings({
    required double newTotalBudget,
    required double newRatePerKwh,
    required int newThresholdPercentage,
    required bool newAlertEnabled,
  }) async {
    try {
      // Check if threshold is changing
      final thresholdChanged = thresholdPercentage != newThresholdPercentage;

      // Check if budget is being edited (not first time setting)
      final isEditing = totalBudget > 0;

      // When editing budget, reset baseline to current totalKwhUsed to reset consumed budget to zero
      if (isEditing) {
        baselineKwhUsed = totalKwhUsed;
        AppLogger.i(
          '[BudgetController] Budget edited - resetting baseline to current totalKwhUsed: $baselineKwhUsed',
        );
      }

      totalBudget = newTotalBudget;
      ratePerKwh = newRatePerKwh;
      thresholdPercentage = newThresholdPercentage;
      alertEnabled = newAlertEnabled;

      final success = await _firestoreService.setBudgetTarget(
        totalBudget: totalBudget,
        ratePerKwh: ratePerKwh,
        thresholdPercentage: thresholdPercentage.toDouble(),
        alertEnabled: alertEnabled,
        baselineKwhUsed: isEditing ? baselineKwhUsed : null,
      );

      if (success) {
        // If threshold changed, reset notification flag to allow new notification for new threshold
        if (thresholdChanged) {
          AppLogger.i(
            '[BudgetController] Threshold changed to $thresholdPercentage% - resetting notification flag',
          );
          _notificationSentForToday = false;
          _lastThresholdThatTriggered =
              null; // Reset to allow notification for new threshold
          // Reset proceed state when threshold changes
          _notificationService.resetProceedState();
        }

        // Recalculate remaining budget from current appliances' usage
        // This ensures remaining budget is calculated dynamically from actual usage
        _recalculateAndMaybeNotify();
      }

      return success;
    } catch (e) {
      debugPrint('[BudgetController] Error saving settings: $e');
      return false;
    }
  }

  /// Get current consumption percentage
  double get consumptionPercentage {
    if (totalBudget == 0) return 0.0;
    final consumedCost = consumedCostValue;
    return (consumedCost / totalBudget * 100).clamp(0.0, 100.0);
  }

  /// Get current consumed cost (calculated from baseline)
  double get consumedCost => consumedCostValue;

  /// Internal method to calculate consumed cost
  double get consumedCostValue {
    final consumedKwh = (totalKwhUsed - baselineKwhUsed).clamp(
      0.0,
      double.infinity,
    );
    return consumedKwh * ratePerKwh;
  }

  /// Get status color based on consumption percentage
  int getStatusColor(int percentage) {
    if (percentage < 70) return 0xFF27AE60; // green
    if (percentage < 90) return 0xFFF39C12; // yellow
    return 0xFFE74C3C; // red
  }

  @override
  void dispose() {
    _disposed = true;

    // Save pending remaining budget before disposing
    _savePendingRemainingBudget();

    _rtdbSub?.cancel();
    _rtdbSub = null;
    _remainingTimer?.cancel();

    try {
      super.dispose();
    } catch (e) {
      // Ignore assertion during hot reload or async races
      // _safeNotifyListeners already prevents notifications when disposed
      debugPrint('[BudgetController] Disposed safely despite active listeners');
    }
  }

  /// Reset notification flag (call this on new day)
  void resetNotificationFlag() {
    _notificationSentForToday = false;
    _lastThresholdThatTriggered = null;
  }

  /// Reset notification for new threshold change
  /// This allows notifications to trigger again when threshold is changed
  void resetNotificationForNewThreshold(int newThreshold) {
    if (_lastThresholdThatTriggered != null &&
        _lastThresholdThatTriggered != newThreshold) {
      AppLogger.i(
        '[BudgetController] Resetting notification for new threshold: $newThreshold% (was $_lastThresholdThatTriggered%)',
      );
      _notificationSentForToday = false;
      _lastThresholdThatTriggered = null;
    }
  }
}
