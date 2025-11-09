import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appliance_model.dart';
import '../services/appliance_service.dart';
import '../services/energy_overview_service.dart';
import '../services/usage_service.dart';
import '../services/notification_service.dart';
import '../services/recent_activity_service.dart';
import '../services/rates_service.dart';
import '../services/appliance_usage_service.dart';
import '../utils/app_logger.dart';

class HomeController extends ChangeNotifier {
  final ApplianceService _applianceService = ApplianceService();
  final EnergyOverviewService _energyOverviewService = EnergyOverviewService();
  final UsageService _usageService = UsageService();
  final NotificationService _notificationService = NotificationService();
  final RecentActivityService _activityService = RecentActivityService();
  final RatesService _ratesService = RatesService();
  final ApplianceUsageService _applianceUsageService = ApplianceUsageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  List<ApplianceModel> _appliances = [];
  Map<String, dynamic> _energyOverviewData = {};
  Map<String, dynamic> _todayUsageData = {};
  List<Map<String, dynamic>> _recentActivities = [];
  double _currentRate = 12.50;
  bool _isLoading = false;
  String? _error;

  // Stream subscriptions and timers for cleanup
  StreamSubscription<List<ApplianceModel>>? _appliancesSubscription;
  StreamSubscription<Map<String, dynamic>>? _usageSubscription;
  Timer? _debounceTimer;

  // Getters
  List<ApplianceModel> get appliances => _appliances;
  Map<String, dynamic> get energyOverviewData => _energyOverviewData;
  Map<String, dynamic> get todayUsageData => _todayUsageData;
  List<Map<String, dynamic>> get recentActivities => _recentActivities;
  double get currentRate => _currentRate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Initialize controller
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      // Check if user is authenticated
      if (currentUser == null) {
        _setError('User not authenticated');
        return;
      }

      // Notification service is initialized in main.dart
      // OneSignal is now used for all notifications
      // Refresh player ID when user logs in
      await _notificationService.refreshPlayerId();

      // Check if monthly reset is needed
      final needsReset = await _energyOverviewService.checkMonthlyReset();
      if (needsReset) {
        await _energyOverviewService.initializeMonthlyData();
        // Note: Monthly reset for appliances is handled automatically
      }

      // Initialize default appliances if none exist
      final existingAppliances = await _getAppliancesOnce();
      if (existingAppliances.isEmpty) {
        await _initializeDefaultAppliances();
      }

      // Load initial data
      await _loadAppliances();
      await _loadEnergyOverviewData();
      await _loadTodayUsageData();
      await _loadRecentActivities();
      await _loadCurrentRate();

      // Set up real-time stream listeners
      _setupStreamListeners();
    } catch (e) {
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Set up real-time stream listeners for appliances and usage
  void _setupStreamListeners() {
    // Cancel existing subscriptions if any
    _appliancesSubscription?.cancel();
    _usageSubscription?.cancel();

    // Listen to appliances changes in real-time
    _appliancesSubscription = _applianceService.listenToAppliances().listen(
      (newAppliances) {
        if (!_listsEqual(_appliances, newAppliances)) {
          _appliances = newAppliances;
          notifyListeners();
          AppLogger.d(
            '[HomeController] Appliances updated from stream: ${newAppliances.length} appliances',
          );
        }
      },
      onError: (error) {
        AppLogger.e('[HomeController] Error in appliances stream: $error');
        _setError('Failed to listen to appliances: $error');
      },
    );

    // Listen to today's usage changes in real-time
    _usageSubscription = _usageService.listenToTodayUsage().listen(
      (newUsageData) {
        _todayUsageData = newUsageData;
        notifyListeners();
        AppLogger.d('[HomeController] Today usage updated from stream');
      },
      onError: (error) {
        AppLogger.e('[HomeController] Error in usage stream: $error');
      },
    );
  }

  // Refresh appliances manually (useful after scene execution)
  Future<void> refreshAppliances() async {
    AppLogger.d('[HomeController] Manually refreshing appliances');
    await _loadAppliances();
  }

  // Load appliances (optimized - only notify if data changed)
  Future<void> _loadAppliances() async {
    try {
      final newAppliances = await _getAppliancesOnce();
      if (!_listsEqual(_appliances, newAppliances)) {
        _appliances = newAppliances;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load appliances: $e');
    }
  }

  // Helper to compare appliance lists efficiently
  bool _listsEqual(List<ApplianceModel> a, List<ApplianceModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].isOn != b[i].isOn ||
          a[i].kwh != b[i].kwh ||
          a[i].watts != b[i].watts ||
          a[i].voltage != b[i].voltage ||
          a[i].current != b[i].current) {
        return false;
      }
    }
    return true;
  }

  // Get appliances once (helper method) - sorted in correct order
  Future<List<ApplianceModel>> _getAppliancesOnce() async {
    final snapshot = await _applianceService.appliancesRef.get();
    if (snapshot.value == null) return <ApplianceModel>[];

    final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
      snapshot.value as Map,
    );
    final appliances =
        data.entries.map((entry) {
          return ApplianceModel.fromRealtimeDB(
            entry.key,
            Map<String, dynamic>.from(entry.value),
          );
        }).toList();

    // Sort appliances in correct order: appliances_001, appliances_002, appliances_003, appliances_004
    return _sortAppliances(appliances);
  }

  // Sort appliances in the correct order
  List<ApplianceModel> _sortAppliances(List<ApplianceModel> appliances) {
    // Define the desired order
    const order = [
      'appliances_001',
      'appliances_002',
      'appliances_003',
      'appliances_004',
    ];

    // Sort by the defined order
    appliances.sort((a, b) {
      final aIndex = order.indexOf(a.id);
      final bIndex = order.indexOf(b.id);

      // If both are in the order list, sort by their index
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      // If only one is in the order list, prioritize it
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // If neither is in the order list, sort alphabetically
      return a.id.compareTo(b.id);
    });

    return appliances;
  }

  // Initialize default appliances
  // Note: kWh and watts are set to 0/null because real values come from ESP32 via Firebase Realtime Database
  Future<void> _initializeDefaultAppliances() async {
    final defaultAppliances = [
      ApplianceModel(
        id: 'appliances_001',
        name: 'Appliances 001',
        icon: 'Iconsax.lamp',
        isOn: false,
        kwh: 0.0, // Will be updated by ESP32
        watts: null, // Will be updated by ESP32
        voltage: null, // Will be updated by ESP32
        current: null, // Will be updated by ESP32
      ),
      ApplianceModel(
        id: 'appliances_002',
        name: 'Appliances 002',
        icon: 'Iconsax.lamp',
        isOn: false,
        kwh: 0.0, // Will be updated by ESP32
        watts: null, // Will be updated by ESP32
        voltage: null, // Will be updated by ESP32
        current: null, // Will be updated by ESP32
      ),
      ApplianceModel(
        id: 'appliances_003',
        name: 'Appliances 003',
        icon: 'Iconsax.socket',
        isOn: false,
        kwh: 0.0, // Will be updated by ESP32
        watts: null, // Will be updated by ESP32
        voltage: null, // Will be updated by ESP32
        current: null, // Will be updated by ESP32
      ),
      ApplianceModel(
        id: 'appliances_004',
        name: 'Appliances 004',
        icon: 'Iconsax.socket',
        isOn: false,
        kwh: 0.0, // Will be updated by ESP32
        watts: null, // Will be updated by ESP32
        voltage: null, // Will be updated by ESP32
        current: null, // Will be updated by ESP32
      ),
    ];

    for (final appliance in defaultAppliances) {
      await _applianceService.addAppliance(appliance);
    }
  }

  // Load energy overview data (optimized - only notify if changed)
  Future<void> _loadEnergyOverviewData() async {
    try {
      final newData = await _energyOverviewService.getEnergyOverviewData();
      if (_energyOverviewData != newData) {
        _energyOverviewData = newData;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load energy data: $e');
    }
  }

  // Load today's usage data (optimized - only notify if changed)
  Future<void> _loadTodayUsageData() async {
    try {
      final newData = await _usageService.rollUpTodayUsage();
      if (_todayUsageData != newData) {
        _todayUsageData = newData;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load today usage data: $e');
    }
  }

  // Load recent activities (optimized - only notify if changed)
  Future<void> _loadRecentActivities() async {
    try {
      final newActivities = await _activityService.getRecentActivities(
        limit: 10,
      );
      if (_recentActivities.length != newActivities.length ||
          !_listsEqualActivities(_recentActivities, newActivities)) {
        _recentActivities = newActivities;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load recent activities: $e');
    }
  }

  // Helper to compare activity lists
  bool _listsEqualActivities(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['timestamp'] != b[i]['timestamp'] ||
          a[i]['type'] != b[i]['type']) {
        return false;
      }
    }
    return true;
  }

  // Load current rate
  Future<void> _loadCurrentRate() async {
    try {
      _currentRate = await _ratesService.getCurrentRate();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load current rate: $e');
    }
  }

  // Toggle appliance (optimized with debouncing)
  Future<void> toggleAppliance(String applianceId, bool isOn) async {
    // Cancel any pending debounce
    _debounceTimer?.cancel();

    // Find appliance index
    final index = _appliances.indexWhere((app) => app.id == applianceId);
    if (index == -1) {
      _setError('Appliance not found: $applianceId');
      return;
    }

    try {
      // Update local state immediately for responsive UI
      final appliance = _appliances[index];
      _appliances[index] = appliance.copyWith(isOn: isOn);
      notifyListeners(); // Immediate UI update

      // Save startTime before toggle (for turn_off calculation)
      final startTimeBeforeToggle =
          appliance.startTime != null
              ? DateTime.tryParse(appliance.startTime!)
              : null;
      final now = DateTime.now();

      // Update Firebase
      await _applianceService.toggleAppliance(applianceId, isOn);

      // Debounce heavy operations (activity log, notifications, data reload)
      _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        try {
          // Get updated appliance from current state
          final updatedAppliance = _appliances.firstWhere(
            (app) => app.id == applianceId,
            orElse: () => appliance,
          );

          // Save usage data to Firestore
          if (isOn) {
            // Appliance turned ON - save turn_on event
            await _applianceUsageService.saveTurnOnEvent(
              applianceId: applianceId,
              applianceName: updatedAppliance.name,
              applianceIcon: updatedAppliance.icon,
              ratePerKwh: _currentRate,
              watts: updatedAppliance.watts,
            );
          } else {
            // Appliance turned OFF - save turn_off event with calculated metrics
            // Use startTime from before toggle (appliance.startTime was set when turned ON)
            final sessionStartTime = startTimeBeforeToggle ?? now;
            final durationSeconds = now.difference(sessionStartTime).inSeconds;
            final watts = appliance.watts ?? 0;

            if (durationSeconds > 0 && watts > 0) {
              await _applianceUsageService.saveTurnOffEvent(
                applianceId: applianceId,
                applianceName: updatedAppliance.name,
                applianceIcon: updatedAppliance.icon,
                ratePerKwh: _currentRate,
                watts: watts,
                durationSeconds: durationSeconds,
                sessionStartTime: sessionStartTime,
              );
            }
          }

          // Add activity log and send notification in parallel
          await Future.wait([
            _activityService.addApplianceActivity(
              applianceName: updatedAppliance.name,
              isOn: isOn,
              applianceId: applianceId,
              applianceIcon: updatedAppliance.icon,
              cost: updatedAppliance.calculateCost(_currentRate),
              kwh: updatedAppliance.kwh,
            ),
            _notificationService.sendApplianceStatusNotification(
              applianceName: updatedAppliance.name,
              isOn: isOn,
              cost: updatedAppliance.calculateCost(_currentRate),
            ),
          ]);

          // Reload data (streams will update automatically, but ensure consistency)
          await Future.wait([_loadTodayUsageData(), _loadRecentActivities()]);
        } catch (e) {
          AppLogger.e(
            '[HomeController] Error in debounced toggle operations: $e',
          );
        }
      });
    } catch (e) {
      // Revert local state on error
      final appliance = _appliances[index];
      _appliances[index] = appliance.copyWith(isOn: !isOn);
      notifyListeners();
      _setError('Failed to toggle appliance: $e');
    }
  }

  // Update appliance
  Future<void> updateAppliance(
    String applianceId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _applianceService.updateAppliance(applianceId, updates);
      await _loadAppliances();
      await _loadTodayUsageData();
    } catch (e) {
      _setError('Failed to update appliance: $e');
    }
  }

  // Add appliance
  Future<void> addAppliance(ApplianceModel appliance) async {
    try {
      await _applianceService.addAppliance(appliance);
      await _loadAppliances();
      await _loadTodayUsageData();
    } catch (e) {
      _setError('Failed to add appliance: $e');
    }
  }

  // Remove appliance
  Future<void> removeAppliance(String applianceId) async {
    try {
      await _applianceService.appliancesRef.child(applianceId).remove();
      await _loadAppliances();
      await _loadTodayUsageData();
    } catch (e) {
      _setError('Failed to remove appliance: $e');
    }
  }

  // Set target cost
  Future<void> setTargetCost(double targetCost) async {
    try {
      // This would typically be handled by the EnergyTargetService
      // For now, we'll just reload the data
      await _loadEnergyOverviewData();
    } catch (e) {
      _setError('Failed to set target cost: $e');
    }
  }

  // Refresh data (optimized - parallel loading)
  Future<void> refresh() async {
    _setLoading(true);
    _clearError();
    try {
      // Load data in parallel for better performance
      await Future.wait([
        _loadAppliances(),
        _loadEnergyOverviewData(),
        _loadTodayUsageData(),
        _loadRecentActivities(),
        _loadCurrentRate(),
      ]);
    } catch (e) {
      _setError('Failed to refresh: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Check and send threshold notifications
  Future<void> checkThresholds() async {
    try {
      final totalCost = _todayUsageData['totalCost'] ?? 0.0;
      final totalKwh = _todayUsageData['totalKwh'] ?? 0.0;
      final targetCost = _energyOverviewData['targetCost'] ?? 1000.0;
      final targetKwh = _energyOverviewData['targetKwh'] ?? 50.0;

      // Check cost threshold (80% of target)
      if (totalCost >= targetCost * 0.8) {
        await _notificationService.sendThresholdReachedNotification(
          type: 'cost',
          currentValue: totalCost,
          thresholdValue: targetCost * 0.8,
          targetValue: targetCost,
        );

        await _activityService.addThresholdActivity(
          thresholdType: 'cost',
          currentValue: totalCost,
          thresholdValue: targetCost * 0.8,
          targetValue: targetCost,
        );
      }

      // Check kWh threshold (80% of target)
      if (totalKwh >= targetKwh * 0.8) {
        await _notificationService.sendThresholdReachedNotification(
          type: 'kwh',
          currentValue: totalKwh,
          thresholdValue: targetKwh * 0.8,
          targetValue: targetKwh,
        );

        await _activityService.addThresholdActivity(
          thresholdType: 'kwh',
          currentValue: totalKwh,
          thresholdValue: targetKwh * 0.8,
          targetValue: targetKwh,
        );
      }
    } catch (e) {
      AppLogger.e('[HomeController] Error checking thresholds', e);
    }
  }

  // Send daily summary notification
  Future<void> sendDailySummary() async {
    try {
      final totalCost = _todayUsageData['totalCost'] ?? 0.0;
      final totalKwh = _todayUsageData['totalKwh'] ?? 0.0;
      final targetCost = _energyOverviewData['targetCost'] ?? 1000.0;
      final targetKwh = _energyOverviewData['targetKwh'] ?? 50.0;

      await _notificationService.sendDailySummaryNotification(
        totalCost: totalCost,
        totalKwh: totalKwh,
        targetCost: targetCost,
        targetKwh: targetKwh,
      );

      await _activityService.addDailySummaryActivity(
        totalCost: totalCost,
        totalKwh: totalKwh,
        targetCost: targetCost,
        targetKwh: targetKwh,
      );
    } catch (e) {
      AppLogger.e('[HomeController] Error sending daily summary', e);
    }
  }

  // Get appliances stream
  Stream<List<ApplianceModel>> getAppliancesStream() {
    return _applianceService.listenToAppliances();
  }

  // Get energy overview data stream
  Stream<Map<String, dynamic>> getEnergyOverviewDataStream() {
    return _energyOverviewService.getEnergyOverviewDataStream();
  }

  // Get today's usage stream
  Stream<Map<String, dynamic>> getTodayUsageStream() {
    return _usageService.listenToTodayUsage();
  }

  // Get recent activities stream
  Stream<List<Map<String, dynamic>>> getRecentActivitiesStream() {
    return _activityService.listenRecentActivities(limit: 10);
  }

  // Get current rate stream
  Stream<double> getCurrentRateStream() {
    return _ratesService.listenToCurrentRate();
  }

  // Get current usage
  double getCurrentUsage() {
    return _energyOverviewData['currentUsage'] ?? 0.0;
  }

  // Get conversion value
  double getConversionValue() {
    return _energyOverviewData['conversionValue'] ?? 0.0;
  }

  // Get today's cost
  double getTodaysCost() {
    return _todayUsageData['totalCost'] ?? 0.0;
  }

  // Get target cost
  double getTargetCost() {
    return _energyOverviewData['targetCost'] ?? 0.0;
  }

  // Get this month's consumption
  double getThisMonthConsumption() {
    return _energyOverviewData['thisMonth'] ?? 0.0;
  }

  // Get today's kWh
  double getTodaysKwh() {
    return _todayUsageData['totalKwh'] ?? 0.0;
  }

  // Get today's usage time
  int getTodaysUsageTime() {
    return _todayUsageData['totalUsageTime'] ?? 0;
  }

  // Format currency
  String formatCurrency(double value) {
    return _ratesService.formatCurrency(value);
  }

  // Format kWh
  String formatKwh(double value) {
    return '${value.toStringAsFixed(2)} kWh';
  }

  // Format usage time
  String formatUsageTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  // Private helper methods (optimized - only notify if value changed)
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // Dispose (cleanup all resources)
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _appliancesSubscription?.cancel();
    _usageSubscription?.cancel();
    super.dispose();
  }
}
