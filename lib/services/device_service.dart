import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service class for managing IoT devices and real-time data
class DeviceService {
  // Singleton pattern
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  // Firebase instances
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Database references
  static const String _devicesPath = 'energySmart/devices';
  static const String _userUsageSummaryPath = 'energySmart/user_usage_summary';
  static const String _alertsPath = 'energySmart/alerts';
  static const String _deviceControlCollection = 'device_control';

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Check if user is authenticated
  bool get _isAuthenticated => _auth.currentUser != null;

  /// Get all devices for current user
  Future<ServiceResult<List<DeviceData>>> getUserDevices() async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;
      final snapshot =
          await _database
              .ref(_devicesPath)
              .orderByChild('userId')
              .equalTo(userId)
              .get();

      if (snapshot.exists) {
        final devices = <DeviceData>[];
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          devices.add(
            DeviceData.fromMap(key, Map<String, dynamic>.from(value)),
          );
        });

        return ServiceResult.success(devices);
      }

      return ServiceResult.success([]);
    } on FirebaseException catch (e) {
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Get device by ID
  Future<ServiceResult<DeviceData?>> getDevice(String deviceId) async {
    try {
      final snapshot = await _database.ref('$_devicesPath/$deviceId').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final device = DeviceData.fromMap(deviceId, data);
        return ServiceResult.success(device);
      }

      return ServiceResult.success(null);
    } on FirebaseException catch (e) {
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Control device (turn on/off)
  Future<ServiceResult<bool>> controlDevice({
    required String deviceId,
    required bool turnOn,
  }) async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final now = DateTime.now();

      // Update device status in Realtime Database
      await _database.ref('$_devicesPath/$deviceId').update({
        'status': turnOn ? 'ON' : 'OFF',
        'relay_state': turnOn,
        'last_updated': now.toIso8601String(),
      });

      // Update device control in Firestore
      await _firestore
          .collection(_deviceControlCollection)
          .doc(deviceId)
          .update({
            'status': turnOn ? 'ON' : 'OFF',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Log device control action
      await _logDeviceAction(deviceId, turnOn ? 'turned_on' : 'turned_off');

      return ServiceResult.success(true);
    } on FirebaseException catch (e) {
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Get real-time device data stream
  Stream<DeviceData?> getDeviceStream(String deviceId) {
    return _database.ref('$_devicesPath/$deviceId').onValue.map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return DeviceData.fromMap(deviceId, data);
      }
      return null;
    });
  }

  /// Get user usage summary
  Future<ServiceResult<UsageSummary?>> getUserUsageSummary() async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;
      final snapshot =
          await _database.ref('$_userUsageSummaryPath/$userId').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final summary = UsageSummary.fromMap(data);
        return ServiceResult.success(summary);
      }

      return ServiceResult.success(null);
    } on FirebaseException catch (e) {
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Get user alerts
  Future<ServiceResult<UserAlerts?>> getUserAlerts() async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;
      final snapshot = await _database.ref('$_alertsPath/$userId').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final alerts = UserAlerts.fromMap(data);
        return ServiceResult.success(alerts);
      }

      return ServiceResult.success(null);
    } on FirebaseException catch (e) {
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Add new device
  Future<ServiceResult<bool>> addDevice({
    required String deviceName,
    required String deviceType,
    required int pin,
  }) async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;
      final deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      // Add to Realtime Database
      await _database.ref('$_devicesPath/$deviceId').set({
        'status': 'OFF',
        'voltage': 0.0,
        'current': 0.0,
        'power': 0.0,
        'energy_kwh': 0.0,
        'relay_state': false,
        'userId': userId,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'last_updated': now.toIso8601String(),
        'isOnline': false,
      });

      // Add to Firestore for configuration
      await _firestore.collection(_deviceControlCollection).doc(deviceId).set({
        'userId': userId,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'pin': pin,
        'status': 'OFF',
        'isOnline': false,
        'lastSeen': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ServiceResult.success(true);
    } on FirebaseException catch (e) {
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Remove device
  Future<ServiceResult<bool>> removeDevice(String deviceId) async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      // Remove from Realtime Database
      await _database.ref('$_devicesPath/$deviceId').remove();

      // Remove from Firestore
      await _firestore
          .collection(_deviceControlCollection)
          .doc(deviceId)
          .delete();

      return ServiceResult.success(true);
    } on FirebaseException catch (e) {
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Log device action
  Future<void> _logDeviceAction(String deviceId, String action) async {
    try {
      if (!_isAuthenticated) return;

      final userId = _currentUserId!;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('energy_usage_logs')
          .add({
            'deviceId': deviceId,
            'action': action,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'device_control',
          });
    } catch (e) {
      debugPrint('Error logging device action: $e');
    }
  }
}

/// Device data model for real-time IoT data
class DeviceData {
  final String id;
  final String status;
  final double voltage;
  final double current;
  final double power;
  final double energyKwh;
  final bool relayState;
  final String userId;
  final String deviceName;
  final String deviceType;
  final DateTime lastUpdated;
  final bool isOnline;
  final Map<String, dynamic> additionalData;

  DeviceData({
    required this.id,
    required this.status,
    required this.voltage,
    required this.current,
    required this.power,
    required this.energyKwh,
    required this.relayState,
    required this.userId,
    required this.deviceName,
    required this.deviceType,
    required this.lastUpdated,
    required this.isOnline,
    this.additionalData = const {},
  });

  factory DeviceData.fromMap(String id, Map<String, dynamic> map) {
    return DeviceData(
      id: id,
      status: map['status'] ?? 'OFF',
      voltage: (map['voltage'] ?? 0.0).toDouble(),
      current: (map['current'] ?? 0.0).toDouble(),
      power: (map['power'] ?? 0.0).toDouble(),
      energyKwh: (map['energy_kwh'] ?? 0.0).toDouble(),
      relayState: map['relay_state'] ?? false,
      userId: map['userId'] ?? '',
      deviceName: map['deviceName'] ?? '',
      deviceType: map['deviceType'] ?? '',
      lastUpdated: DateTime.parse(
        map['last_updated'] ?? DateTime.now().toIso8601String(),
      ),
      isOnline: map['isOnline'] ?? false,
      additionalData: Map<String, dynamic>.from(map['additionalData'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'voltage': voltage,
      'current': current,
      'power': power,
      'energy_kwh': energyKwh,
      'relay_state': relayState,
      'userId': userId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'last_updated': lastUpdated.toIso8601String(),
      'isOnline': isOnline,
      'additionalData': additionalData,
    };
  }
}

/// Usage summary model
class UsageSummary {
  final double totalEnergyToday;
  final double totalEnergyWeek;
  final double totalEnergyMonth;
  final int peakUsageHour;
  final double averageDailyUsage;
  final double costToday;
  final double costWeek;
  final double costMonth;
  final DateTime lastUpdate;
  final int devicesCount;
  final int onlineDevices;
  final double savingsPercentage;

  UsageSummary({
    required this.totalEnergyToday,
    required this.totalEnergyWeek,
    required this.totalEnergyMonth,
    required this.peakUsageHour,
    required this.averageDailyUsage,
    required this.costToday,
    required this.costWeek,
    required this.costMonth,
    required this.lastUpdate,
    required this.devicesCount,
    required this.onlineDevices,
    required this.savingsPercentage,
  });

  factory UsageSummary.fromMap(Map<String, dynamic> map) {
    return UsageSummary(
      totalEnergyToday: (map['total_energy_today'] ?? 0.0).toDouble(),
      totalEnergyWeek: (map['total_energy_week'] ?? 0.0).toDouble(),
      totalEnergyMonth: (map['total_energy_month'] ?? 0.0).toDouble(),
      peakUsageHour: map['peak_usage_hour'] ?? 0,
      averageDailyUsage: (map['average_daily_usage'] ?? 0.0).toDouble(),
      costToday: (map['cost_today'] ?? 0.0).toDouble(),
      costWeek: (map['cost_week'] ?? 0.0).toDouble(),
      costMonth: (map['cost_month'] ?? 0.0).toDouble(),
      lastUpdate: DateTime.parse(
        map['last_update'] ?? DateTime.now().toIso8601String(),
      ),
      devicesCount: map['devices_count'] ?? 0,
      onlineDevices: map['online_devices'] ?? 0,
      savingsPercentage: (map['savings_percentage'] ?? 0.0).toDouble(),
    );
  }
}

/// User alerts model
class UserAlerts {
  final bool highUsage;
  final DateTime? lastTriggered;
  final double currentConsumption;
  final double threshold;
  final double thresholdPercentage;
  final double energyThreshold;
  final bool thresholdAlertEnabled;
  final DateTime lastUpdated;
  final List<AlertHistory> alertHistory;

  UserAlerts({
    required this.highUsage,
    this.lastTriggered,
    required this.currentConsumption,
    required this.threshold,
    required this.thresholdPercentage,
    required this.energyThreshold,
    required this.thresholdAlertEnabled,
    required this.lastUpdated,
    this.alertHistory = const [],
  });

  factory UserAlerts.fromMap(Map<String, dynamic> map) {
    final history = map['alert_history'] as List<dynamic>? ?? [];
    return UserAlerts(
      highUsage: map['high_usage'] ?? false,
      lastTriggered:
          map['last_triggered'] != null
              ? DateTime.parse(map['last_triggered'])
              : null,
      currentConsumption: (map['current_consumption'] ?? 0.0).toDouble(),
      threshold: (map['threshold'] ?? 0.0).toDouble(),
      thresholdPercentage: (map['threshold_percentage'] ?? 0.0).toDouble(),
      energyThreshold: (map['energy_threshold'] ?? 0.0).toDouble(),
      thresholdAlertEnabled: map['threshold_alert_enabled'] ?? false,
      lastUpdated: DateTime.parse(
        map['last_updated'] ?? DateTime.now().toIso8601String(),
      ),
      alertHistory:
          history
              .map((h) => AlertHistory.fromMap(Map<String, dynamic>.from(h)))
              .toList(),
    );
  }
}

/// Alert history model
class AlertHistory {
  final DateTime timestamp;
  final String type;
  final String message;
  final Map<String, dynamic> additionalData;

  AlertHistory({
    required this.timestamp,
    required this.type,
    required this.message,
    this.additionalData = const {},
  });

  factory AlertHistory.fromMap(Map<String, dynamic> map) {
    return AlertHistory(
      timestamp: DateTime.parse(map['timestamp']),
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      additionalData: Map<String, dynamic>.from(map['additionalData'] ?? {}),
    );
  }
}

/// Generic result class for service operations
class ServiceResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  ServiceResult._(this.isSuccess, this.data, this.error);

  factory ServiceResult.success(T data) => ServiceResult._(true, data, null);
  factory ServiceResult.error(String error) =>
      ServiceResult._(false, null, error);
}
