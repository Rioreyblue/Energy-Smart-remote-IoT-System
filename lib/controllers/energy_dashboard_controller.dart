import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/usage_service.dart';
import '../services/power_rate_service.dart';
import '../utils/app_logger.dart';

/// Optimized controller for energy dashboard to prevent unnecessary rebuilds
class EnergyDashboardController extends ChangeNotifier {
  final UsageService _usageService = UsageService();
  final PowerRateService _powerRateService = PowerRateService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _updateTimer;

  // Stream subscriptions
  StreamSubscription<Map<String, dynamic>>? _usageSubscription;
  StreamSubscription<Map<String, dynamic>>? _monthlySubscription;
  StreamSubscription<DatabaseEvent>? _targetSubscription;
  StreamSubscription<double>? _powerRateSubscription;
  StreamSubscription<DatabaseEvent>? _remainingBudgetSubscription;

  // Current values
  double _currentUsage = 0.0;
  double _currentRate = 12.50;
  double _todaysCost = 0.0;
  double _targetCost = 0.0;
  double _thisMonth = 0.0;
  bool _isLoading = true;
  String? _error;

  // Getters
  double get currentUsage => _currentUsage;
  double get currentRate => _currentRate;
  double get todaysCost => _todaysCost;
  double get targetCost => _targetCost;
  double get thisMonth => _thisMonth;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get conversionValue => _currentUsage * _currentRate;

  /// Get current user ID
  String get _userId => _auth.currentUser?.uid ?? '';

  /// Get database reference for target cost (target_cost) in Realtime DB
  DatabaseReference get _targetCostRef =>
      _database.ref('users/$_userId/target_threshold/target_cost');

  /// Get database reference for remaining budget in Realtime DB
  DatabaseReference get _remainingBudgetRef =>
      _database.ref('users/$_userId/target_threshold/remaining_budget');

  /// Get appliances reference from Realtime DB
  DatabaseReference get _appliancesRef =>
      _database.ref('users/$_userId/appliances');

  /// Get Firestore reference for target cost (primary source)
  DocumentReference get _targetCostFirestoreRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_userId)
      .collection('budget_target')
      .doc('current');

  @override
  void dispose() {
    _usageSubscription?.cancel();
    _monthlySubscription?.cancel();
    _targetSubscription?.cancel();
    _powerRateSubscription?.cancel();
    _remainingBudgetSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  /// Initialize the controller and start listening to streams
  void initialize() {
    // Ensure we have a logged-in user before resolving RTDB paths
    if (_auth.currentUser == null) {
      AppLogger.w(
        '[EnergyDashboardController] initialize() called with no user; waiting for auth.',
      );
      _auth.authStateChanges().firstWhere((u) => u != null).then((_) {
        AppLogger.i(
          '[EnergyDashboardController] Auth ready, re-running initialize().',
        );
        initialize();
      });
      return;
    }
    _isLoading = true;
    notifyListeners();

    // Listen to today's usage data
    _usageSubscription = _usageService.listenToTodayUsage().listen(
      (usageData) {
        _currentUsage = usageData['totalKwh'] ?? 0.0;
        _todaysCost = usageData['totalCost'] ?? 0.0;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    // Start monthly/daily updaters and listen to Firestore-backed monthly totals
    _usageService.startMonthlyRealtimeUpdater();
    _usageService.startDailyRealtimeMirror();
    _usageService.startTodayRealtimeUpdater();
    _monthlySubscription = _usageService.listenToThisMonthUsageFirestore().listen(
      (monthlyData) {
        _thisMonth = monthlyData['totalCost'] ?? 0.0;
        notifyListeners();
      },
      onError: (error) {
        AppLogger.w(
          '[EnergyDashboardController] Error loading monthly Firestore data: $error',
        );
      },
    );

    // Initialize power rate service and listen for updates
    _powerRateService.initialize().then((_) {
      _currentRate = _powerRateService.currentRate;
      notifyListeners();
    });

    _powerRateSubscription ??= _powerRateService.rateStream.listen(
      (rate) {
        if ((_currentRate - rate).abs() < 0.00005) return;
        _currentRate = rate;
        AppLogger.i(
          '[EnergyDashboardController] Power rate updated to: $_currentRate',
        );
        notifyListeners();
      },
      onError: (error) {
        AppLogger.w(
          '[EnergyDashboardController] Error listening to power rate: $error',
        );
      },
    );

    // Set up real-time listener FIRST to catch all updates immediately
    // This ensures we receive every update from RTDB remaining_budget in real-time
    _remainingBudgetSubscription?.cancel(); // Cancel any existing subscription
    _remainingBudgetSubscription = _remainingBudgetRef.onValue.listen(
      (event) {
        // Log every event received for debugging
        AppLogger.d(
          '[EnergyDashboardController] RTDB remaining_budget event received (exists: ${event.snapshot.exists})',
        );

        if (!event.snapshot.exists) {
          AppLogger.d(
            '[EnergyDashboardController] RTDB remaining_budget snapshot does not exist',
          );
          return;
        }

        final value = event.snapshot.value;
        num? parsed;

        if (value is num) {
          parsed = value;
        } else if (value is String) {
          parsed = num.tryParse(value);
        } else if (value != null) {
          // Try to convert other types
          try {
            parsed = (value as dynamic).toDouble();
          } catch (e) {
            AppLogger.w(
              '[EnergyDashboardController] Could not parse remaining_budget value: $value',
            );
          }
        }

        if (parsed != null) {
          final newTargetCost = parsed.toDouble();
          // Use epsilon comparison for floating point to catch small changes
          // This ensures we catch all updates even with minor precision differences
          final difference = (newTargetCost - _targetCost).abs();
          if (difference > 0.001 || _targetCost == 0.0) {
            _targetCost = newTargetCost;
            AppLogger.i(
              '[EnergyDashboardController] RTDB remaining_budget updated -> $_targetCost (diff: $difference)',
            );
            notifyListeners();
          } else {
            // Even for very small changes, log to ensure listener is working
            AppLogger.d(
              '[EnergyDashboardController] RTDB remaining_budget value similar: $_targetCost (diff: $difference)',
            );
          }
        } else if (value == null) {
          // Handle null value - might mean budget was reset
          if (_targetCost != 0.0) {
            AppLogger.d(
              '[EnergyDashboardController] RTDB remaining_budget is null, keeping current value',
            );
          }
        } else {
          AppLogger.w(
            '[EnergyDashboardController] remaining_budget non-numeric or null: $value (type: ${value.runtimeType})',
          );
        }
      },
      onError: (error) {
        AppLogger.e(
          '[EnergyDashboardController] Error listening to remaining_budget: $error',
        );
        // Don't update targetCost on error, keep current value
      },
      cancelOnError: false, // Keep listening even if there's an error
    );

    // Load initial value from RTDB (fallback to Firestore if needed)
    // This runs after listener is set up, so listener will catch any updates
    _loadTargetCostFromRTDBFirst();

    // Load monthly data initially
    _usageService
        .getThisMonthUsage()
        .then((monthlyData) {
          _thisMonth = monthlyData['totalCost'] ?? 0.0;
          notifyListeners();
        })
        .catchError((error) {
          AppLogger.w(
            '[EnergyDashboardController] Error loading initial monthly data: $error',
          );
        });

    // Start periodic live updates for current usage and today's cost
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final result = await _calculateLiveUsageFromAppliances();
        final newUsage = result['totalKwh'] ?? 0.0;
        final newCost = result['totalCost'] ?? 0.0;
        if (newUsage != _currentUsage || newCost != _todaysCost) {
          _currentUsage = newUsage;
          _todaysCost = newCost;
          notifyListeners();
        }
      } catch (_) {
        // ignore
      }
    });
  }

  /// Calculate live usage and cost from appliances without writing to DB
  Future<Map<String, double>> _calculateLiveUsageFromAppliances() async {
    if (_userId.isEmpty) return {'totalKwh': 0.0, 'totalCost': 0.0};

    final snapshot = await _appliancesRef.get();
    if (!snapshot.exists || snapshot.value == null) {
      return {'totalKwh': 0.0, 'totalCost': 0.0};
    }

    final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
      snapshot.value as Map,
    );

    double totalKwh = 0.0;
    final now = DateTime.now();

    for (final entry in data.entries) {
      final applianceData = Map<String, dynamic>.from(entry.value as Map);
      final baseKwh = (applianceData['kwh'] ?? 0.0).toDouble();
      totalKwh += baseKwh;

      final bool isOn = applianceData['isOn'] == true;
      final String? startTimeStr = applianceData['startTime'] as String?;
      final int watts =
          (applianceData['watts'] ?? 0) is int
              ? applianceData['watts'] as int
              : (applianceData['watts'] ?? 0.0).toInt();

      if (isOn &&
          startTimeStr != null &&
          startTimeStr.isNotEmpty &&
          watts > 0) {
        final startTime = DateTime.tryParse(startTimeStr);
        if (startTime != null) {
          final seconds = now.difference(startTime).inSeconds;
          final hours = seconds / 3600.0;
          final liveKwh = (watts * hours) / 1000.0;
          totalKwh += liveKwh;
        }
      }
    }

    final totalCost = totalKwh * _currentRate;
    return {'totalKwh': totalKwh, 'totalCost': totalCost};
  }

  /// Load target cost from RTDB remaining_budget first (primary), fallback to Firestore
  Future<void> _loadTargetCostFromRTDBFirst() async {
    if (_userId.isEmpty) return;

    try {
      // Try RTDB remaining_budget first (primary source for Home display)
      final remainingBudgetSnap = await _remainingBudgetRef.get();
      if (remainingBudgetSnap.exists && remainingBudgetSnap.value != null) {
        final value = remainingBudgetSnap.value;
        if (value is num) {
          _targetCost = value.toDouble();
          AppLogger.i(
            '[EnergyDashboardController] Loaded target cost from RTDB remaining_budget: $_targetCost',
          );
          notifyListeners();
          return; // RTDB has value, no need for Firestore fallback
        }
      }

      // Fallback to Firestore if RTDB remaining_budget is empty
      AppLogger.d(
        '[EnergyDashboardController] RTDB remaining_budget empty, falling back to Firestore',
      );
      final firestoreDoc = await _targetCostFirestoreRef.get();
      if (firestoreDoc.exists) {
        final data = firestoreDoc.data() as Map<String, dynamic>?;
        final targetCostValue = data?['totalBudget'] ?? data?['target_cost'];
        if (targetCostValue != null) {
          _targetCost = (targetCostValue as num).toDouble();
          // Sync to RTDB remaining_budget for future real-time updates
          await _remainingBudgetRef.set(_targetCost);
          AppLogger.i(
            '[EnergyDashboardController] Loaded target cost from Firestore (fallback): $_targetCost',
          );
          notifyListeners();
          return;
        }
      }

      // No value found in either source
      _targetCost = 0.0;
      notifyListeners();
    } catch (e) {
      AppLogger.e('[EnergyDashboardController] Error loading target cost: $e');
      _targetCost = 0.0;
      notifyListeners();
    }
  }

  /// Load target cost from Firestore first, then sync to Realtime DB
  Future<void> _loadTargetCost() async {
    if (_userId.isEmpty) return;

    try {
      // Try to load from Firestore first (primary source)
      final firestoreDoc = await _targetCostFirestoreRef.get();
      if (firestoreDoc.exists) {
        final data = firestoreDoc.data() as Map<String, dynamic>?;
        // Prefer totalBudget from budget_target/current, fallback to target_cost mirror
        final targetCostValue = data?['totalBudget'] ?? data?['target_cost'];
        if (targetCostValue != null) {
          _targetCost = (targetCostValue as num).toDouble();
          // Sync to Realtime DB for real-time updates
          await _targetCostRef.set(_targetCost);
          AppLogger.i(
            '[EnergyDashboardController] Loaded target cost from Firestore: $_targetCost',
          );
          notifyListeners();
          _setupRealtimeListener();
          return;
        }
      }

      // Fallback to Realtime DB if Firestore doesn't have it
      final snapshot = await _targetCostRef.get();
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        if (value is num) {
          _targetCost = value.toDouble();
          // Sync back to Firestore
          await _targetCostFirestoreRef.set({
            'target_cost': _targetCost,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          AppLogger.i(
            '[EnergyDashboardController] Loaded target cost from Realtime DB: $_targetCost',
          );
        } else {
          _targetCost = 0.0;
        }
      } else {
        _targetCost = 0.0;
      }

      notifyListeners();

      // Now set up real-time listener
      _setupRealtimeListener();
    } catch (e) {
      AppLogger.e('[EnergyDashboardController] Error loading target cost: $e');
      _targetCost = 0.0;
      notifyListeners();
    }
  }

  /// Set up real-time listener for target cost changes (target_cost)
  void _setupRealtimeListener() {
    if (_userId.isEmpty) return;

    _targetSubscription = _targetCostRef.onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final value = event.snapshot.value;
          // target_cost is a direct numeric value
          if (value is num) {
            _targetCost = value.toDouble();
          } else {
            _targetCost = 0.0;
          }
        } else {
          _targetCost = 0.0;
        }

        notifyListeners();
      },
      onError: (error) {
        _targetCost = 0.0;
        notifyListeners();
      },
    );
  }

  /// Refresh data manually
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Reload target cost
      await _loadTargetCost();

      // Refresh power rate
      await _powerRateService.refresh();
      _currentRate = _powerRateService.currentRate;

      // Load monthly data initially
      final monthlyData = await _usageService.getThisMonthUsage();
      _thisMonth = monthlyData['totalCost'] ?? 0.0;

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get formatted usage text
  String getFormattedUsage() {
    return '${_currentUsage.toStringAsFixed(4)} kWh';
  }

  /// Get formatted cost text
  String getFormattedCost() {
    return '₱${conversionValue.toStringAsFixed(4)}';
  }

  /// Get formatted today's cost
  String getFormattedTodaysCost() {
    return '₱${_todaysCost.toStringAsFixed(4)}';
  }

  /// Get formatted target cost
  String getFormattedTargetCost() {
    return '₱${_targetCost.toStringAsFixed(4)}';
  }

  /// Get formatted this month cost
  String getFormattedThisMonth() {
    return '₱${_thisMonth.toStringAsFixed(2)}';
  }

  /// Get current target cost value from Firestore (primary source)
  Future<double> getCurrentTargetCost() async {
    if (_userId.isEmpty) return 0.0;

    try {
      // Try Firestore first
      final firestoreDoc = await _targetCostFirestoreRef.get();
      if (firestoreDoc.exists) {
        final data = firestoreDoc.data() as Map<String, dynamic>?;
        final targetCostValue = data?['totalBudget'] ?? data?['target_cost'];
        if (targetCostValue != null) {
          return (targetCostValue as num).toDouble();
        }
      }

      // Fallback to Realtime DB
      final snapshot = await _targetCostRef.get();
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        if (value is num) {
          return value.toDouble();
        }
      }
    } catch (e) {
      AppLogger.w('[EnergyDashboardController] Error getting target cost: $e');
    }
    return 0.0;
  }
}
