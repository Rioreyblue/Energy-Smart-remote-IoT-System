import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/appliance_model.dart';
import 'appliance_service.dart';
import 'recent_activity_service.dart';
import 'notification_service.dart';
import '../utils/app_logger.dart';

/// Service for managing device control operations with optimized performance
class DeviceControlService {
  static final DeviceControlService _instance =
      DeviceControlService._internal();
  factory DeviceControlService() => _instance;
  DeviceControlService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final ApplianceService _applianceService = ApplianceService();
  final RecentActivityService _activityService = RecentActivityService();
  final NotificationService _notificationService = NotificationService();

  // Stream controllers for real-time updates
  final StreamController<List<ApplianceModel>> _appliancesController =
      StreamController<List<ApplianceModel>>.broadcast();
  final StreamController<Map<String, dynamic>> _usageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Cache for preventing unnecessary updates
  Map<String, ApplianceModel> _applianceCache = {};
  Map<String, dynamic> _lastUsageData = {};
  Timer? _debounceTimer;

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Stream of appliances with optimized updates
  Stream<List<ApplianceModel>> get appliancesStream =>
      _appliancesController.stream;

  /// Stream of usage data with optimized updates
  Stream<Map<String, dynamic>> get usageStream => _usageController.stream;

  /// Initialize the service and start listening to changes
  Future<void> initialize() async {
    if (_userId.isEmpty) return;

    // Listen to appliances changes
    _database.ref('users/$_userId/appliances').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final appliances = <ApplianceModel>[];

        data.forEach((key, value) {
          final applianceData = Map<String, dynamic>.from(value);
          appliances.add(ApplianceModel.fromMap(key, applianceData));
        });

        // Sort appliances in correct order: appliances_001, appliances_002, appliances_003, appliances_004
        final sortedAppliances = _sortAppliances(appliances);

        // Only update if there are actual changes
        if (_hasApplianceChanges(sortedAppliances)) {
          _appliancesController.add(sortedAppliances);
          _updateApplianceCache(sortedAppliances);
        }
      }
    });

    // Listen to today's usage changes
    _database.ref('users/$_userId/todayUsage').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Only update if there are actual changes
        if (_hasUsageChanges(data)) {
          _usageController.add(data);
          _lastUsageData = data;
        }
      }
    });
  }

  /// Toggle appliance with optimized performance
  Future<void> toggleAppliance(String applianceId, bool isOn) async {
    try {
      // Cancel any pending debounce timer
      _debounceTimer?.cancel();

      // Update Firebase immediately
      await _applianceService.toggleAppliance(applianceId, isOn);

      // Debounce local updates to prevent rapid rebuilds
      _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        await _updateLocalState(applianceId, isOn);
      });
    } catch (e) {
      AppLogger.i('[DeviceControlService] Error toggling appliance: $e');
      rethrow;
    }
  }

  /// Update local state after successful Firebase update
  Future<void> _updateLocalState(String applianceId, bool isOn) async {
    try {
      // Get updated appliance data
      final appliance = await _getApplianceById(applianceId);
      if (appliance != null) {
        // Update cache
        _applianceCache[applianceId] = appliance.copyWith(isOn: isOn);

        // Add activity log (debounced)
        await _activityService.addApplianceActivity(
          applianceName: appliance.name,
          isOn: isOn,
          applianceId: applianceId,
          cost: appliance.calculateCost(12.50), // Use current rate
          kwh: appliance.kwh,
        );

        // Send notification (debounced)
        await _notificationService.sendApplianceStatusNotification(
          applianceName: appliance.name,
          isOn: isOn,
          cost: appliance.calculateCost(12.50),
        );
      }
    } catch (e) {
      AppLogger.i('[DeviceControlService] Error updating local state: $e');
    }
  }

  /// Get appliance by ID from cache or Firebase
  Future<ApplianceModel?> _getApplianceById(String applianceId) async {
    // Check cache first
    if (_applianceCache.containsKey(applianceId)) {
      return _applianceCache[applianceId];
    }

    // Fetch from Firebase
    try {
      final snapshot =
          await _database.ref('users/$_userId/appliances/$applianceId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final appliance = ApplianceModel.fromMap(applianceId, data);
        _applianceCache[applianceId] = appliance;
        return appliance;
      }
    } catch (e) {
      AppLogger.i('[DeviceControlService] Error getting appliance: $e');
    }
    return null;
  }

  /// Check if appliances have actually changed
  bool _hasApplianceChanges(List<ApplianceModel> newAppliances) {
    if (_applianceCache.length != newAppliances.length) return true;

    for (final appliance in newAppliances) {
      final cached = _applianceCache[appliance.id];
      if (cached == null ||
          cached.isOn != appliance.isOn ||
          cached.kwh != appliance.kwh ||
          cached.totalUsageTime != appliance.totalUsageTime) {
        return true;
      }
    }
    return false;
  }

  /// Check if usage data has actually changed
  bool _hasUsageChanges(Map<String, dynamic> newData) {
    if (_lastUsageData.isEmpty) return true;

    return _lastUsageData['totalKwh'] != newData['totalKwh'] ||
        _lastUsageData['totalCost'] != newData['totalCost'] ||
        _lastUsageData['totalUsageTime'] != newData['totalUsageTime'];
  }

  /// Update appliance cache
  void _updateApplianceCache(List<ApplianceModel> appliances) {
    _applianceCache.clear();
    for (final appliance in appliances) {
      _applianceCache[appliance.id] = appliance;
    }
  }

  /// Get current appliances from cache (sorted)
  List<ApplianceModel> getCurrentAppliances() {
    final appliances = _applianceCache.values.toList();
    return _sortAppliances(appliances);
  }

  /// Get current usage data from cache
  Map<String, dynamic> getCurrentUsageData() {
    return _lastUsageData;
  }

  /// Sort appliances in the correct order
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
      // If neither is in the inside list, sort alphabetically
      return a.id.compareTo(b.id);
    });

    return appliances;
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _appliancesController.close();
    _usageController.close();
  }
}
