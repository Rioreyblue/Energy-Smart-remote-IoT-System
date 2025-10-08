import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exercise_app/models/goals_model.dart';

/// Service class for managing energy goals and meter readings
/// Handles both Firestore and Realtime Database operations
class GoalsService {
  // Singleton pattern
  static final GoalsService _instance = GoalsService._internal();
  factory GoalsService() => _instance;
  GoalsService._internal();

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _estimatedBillCollection = 'estimatedBill';
  static const String _energyUsageLogsCollection = 'energy_usage_logs';
  static const String _notificationsCollection = 'notifications';

  // Realtime Database references
  static const String _userUsageSummaryPath = 'energySmart/user_usage_summary';

  // Local state for offline support
  GoalsModel? _currentGoals;
  List<MeterReadingModel> _meterReadings = [];
  String? _userType;
  bool _isOnline = true;

  // Getters
  GoalsModel? get currentGoals => _currentGoals;
  List<MeterReadingModel> get meterReadings => _meterReadings;
  String? get userType => _userType;
  bool get isOnline => _isOnline;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Check if user is authenticated
  bool get _isAuthenticated => _auth.currentUser != null;

  /// Save energy threshold goals to Firestore
  Future<ServiceResult<bool>> saveEnergyThreshold({
    required double threshold,
    required bool alertEnabled,
  }) async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;
      final now = DateTime.now();

      // Update local state first for immediate UI feedback
      _currentGoals = GoalsModel(
        id: userId,
        energyThreshold: threshold,
        thresholdAlertEnabled: alertEnabled,
        createdAt: _currentGoals?.createdAt ?? now,
        updatedAt: now,
      );

      // Save to Firestore
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('goals')
          .doc('energy_threshold')
          .set({
            'energyThreshold': threshold,
            'thresholdAlertEnabled': alertEnabled,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt':
                _currentGoals?.createdAt != null
                    ? Timestamp.fromDate(_currentGoals!.createdAt)
                    : FieldValue.serverTimestamp(),
          });

      // Update Realtime Database for real-time alerts
      await _database.ref('energySmart/alerts/$userId').update({
        'energy_threshold': threshold,
        'threshold_alert_enabled': alertEnabled,
        'last_updated': now.toIso8601String(),
      });

      return ServiceResult.success(true);
    } on FirebaseException catch (e) {
      _isOnline = false;
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Save meter reading to Firestore
  Future<ServiceResult<bool>> saveMeterReading({
    required double ratePerKwh,
    required double previousReading,
    required double presentReading,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;
      final consumption = presentReading - previousReading;
      final estimatedBill = consumption * ratePerKwh;
      final now = DateTime.now();

      final reading = MeterReadingModel(
        id: now.millisecondsSinceEpoch.toString(),
        ratePerKwh: ratePerKwh,
        previousReading: previousReading,
        presentReading: presentReading,
        startDate: startDate,
        endDate: endDate,
        consumption: consumption,
        estimatedBill: estimatedBill,
        createdAt: now,
      );

      // Update local state
      _meterReadings.insert(0, reading);

      // Save to Firestore
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_estimatedBillCollection)
          .add(reading.toMap());

      // Save to energy usage logs
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_energyUsageLogsCollection)
          .add({
            'deviceId': 'main_meter',
            'deviceName': 'Main Energy Meter',
            'consumption': consumption,
            'duration': endDate.difference(startDate).inHours,
            'timestamp': FieldValue.serverTimestamp(),
            'ratePerKwh': ratePerKwh,
            'estimatedBill': estimatedBill,
          });

      // Update Realtime Database usage summary
      await _updateUsageSummary(userId, consumption);

      return ServiceResult.success(true);
    } on FirebaseException catch (e) {
      _isOnline = false;
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Get energy threshold from Firestore
  Future<ServiceResult<GoalsModel?>> getEnergyThreshold() async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;

      // Try to get from Firestore
      final doc =
          await _firestore
              .collection(_usersCollection)
              .doc(userId)
              .collection('goals')
              .doc('energy_threshold')
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        final goals = GoalsModel(
          id: userId,
          energyThreshold: data['energyThreshold']?.toDouble() ?? 0.0,
          thresholdAlertEnabled: data['thresholdAlertEnabled'] ?? false,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          updatedAt: (data['updatedAt'] as Timestamp).toDate(),
        );
        _currentGoals = goals;
        return ServiceResult.success(goals);
      }

      return ServiceResult.success(null);
    } on FirebaseException {
      _isOnline = false;
      // Return local state if offline
      return ServiceResult.success(_currentGoals);
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Get meter readings history from Firestore
  Future<ServiceResult<List<MeterReadingModel>>> getMeterReadingsHistory({
    int limit = 50,
  }) async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;

      final query =
          await _firestore
              .collection(_usersCollection)
              .doc(userId)
              .collection(_estimatedBillCollection)
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      final readings =
          query.docs
              .map((doc) => MeterReadingModel.fromMap(doc.id, doc.data()))
              .toList();

      _meterReadings = readings;
      return ServiceResult.success(readings);
    } on FirebaseException {
      _isOnline = false;
      // Return local state if offline
      return ServiceResult.success(_meterReadings);
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Save user type to Firestore
  Future<ServiceResult<bool>> saveUserType(String userType) async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;

      // Update local state
      _userType = userType;

      // Save to Firestore
      await _firestore.collection(_usersCollection).doc(userId).update({
        'userType': userType,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ServiceResult.success(true);
    } on FirebaseException catch (e) {
      _isOnline = false;
      return ServiceResult.error('Firebase error: ${e.message}');
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Get user type from Firestore
  Future<ServiceResult<String?>> getUserType() async {
    try {
      if (!_isAuthenticated) {
        return ServiceResult.error('User not authenticated');
      }

      final userId = _currentUserId!;

      final doc =
          await _firestore.collection(_usersCollection).doc(userId).get();

      if (doc.exists) {
        final userType = doc.data()?['userType'] as String?;
        _userType = userType;
        return ServiceResult.success(userType);
      }

      return ServiceResult.success(null);
    } on FirebaseException {
      _isOnline = false;
      // Return local state if offline
      return ServiceResult.success(_userType);
    } catch (e) {
      return ServiceResult.error('Unexpected error: $e');
    }
  }

  /// Check if current consumption exceeds threshold
  Future<ServiceResult<bool>> checkThresholdAlert(
    double currentConsumption,
  ) async {
    try {
      final goalsResult = await getEnergyThreshold();
      if (!goalsResult.isSuccess || goalsResult.data == null) {
        return ServiceResult.success(false);
      }

      final goals = goalsResult.data!;
      if (!goals.thresholdAlertEnabled) {
        return ServiceResult.success(false);
      }

      final threshold80Percent = goals.energyThreshold * 0.8;
      final shouldAlert = currentConsumption >= threshold80Percent;

      // Update Realtime Database alert status
      if (shouldAlert) {
        await _database.ref('energySmart/alerts/${_currentUserId}').update({
          'high_usage': true,
          'last_triggered': DateTime.now().toIso8601String(),
          'current_consumption': currentConsumption,
          'threshold': goals.energyThreshold,
        });
      }

      return ServiceResult.success(shouldAlert);
    } catch (e) {
      return ServiceResult.error('Error checking threshold: $e');
    }
  }

  /// Send threshold alert notification
  Future<void> sendThresholdAlert(
    BuildContext context,
    double currentConsumption,
  ) async {
    final alertResult = await checkThresholdAlert(currentConsumption);
    if (!alertResult.isSuccess || !alertResult.data!) return;

    final goals = _currentGoals;
    if (goals == null) return;

    final threshold80Percent = goals.energyThreshold * 0.8;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Energy Alert: You have reached 80% of your threshold (${threshold80Percent.toStringAsFixed(1)} kWh)',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }

    // Save notification to Firestore
    await _saveNotification(
      'Energy Alert',
      'You have reached 80% of your energy threshold!',
      'threshold_alert',
    );
  }

  /// Calculate energy savings compared to previous period
  double calculateEnergySavings(List<MeterReadingModel> readings) {
    if (readings.length < 2) return 0.0;

    final current = readings.first.consumption;
    final previous = readings[1].consumption;

    if (previous == 0) return 0.0;
    return ((previous - current) / previous) * 100;
  }

  /// Get consumption trend
  String getConsumptionTrend(List<MeterReadingModel> readings) {
    if (readings.length < 3) return 'insufficient_data';

    final recent = readings.take(3).map((r) => r.consumption).toList();
    final avgRecent = recent.reduce((a, b) => a + b) / recent.length;
    final oldest = readings[2].consumption;

    if (avgRecent > oldest * 1.1) return 'increasing';
    if (avgRecent < oldest * 0.9) return 'decreasing';
    return 'stable';
  }

  /// Generate energy efficiency tips
  List<String> generateEfficiencyTips(List<MeterReadingModel> readings) {
    final tips = <String>[];
    final trend = getConsumptionTrend(readings);

    if (trend == 'increasing') {
      tips.addAll([
        'Consider using energy-efficient appliances',
        'Turn off lights when not in use',
        'Use natural lighting during the day',
        'Set air conditioning to 24-26°C',
        'Unplug devices when not in use',
      ]);
    } else if (trend == 'decreasing') {
      tips.addAll([
        'Great job! Your energy consumption is decreasing',
        'Keep up the good energy-saving habits',
        'Consider setting even more ambitious goals',
      ]);
    } else {
      tips.addAll([
        'Your energy consumption is stable',
        'Try implementing small changes to reduce usage',
        'Monitor your peak usage times',
      ]);
    }

    return tips;
  }

  /// Update usage summary in Realtime Database
  Future<void> _updateUsageSummary(String userId, double consumption) async {
    try {
      final now = DateTime.now();

      final summaryRef = _database.ref('$_userUsageSummaryPath/$userId');
      final snapshot = await summaryRef.get();

      Map<String, dynamic> summary = {};
      if (snapshot.exists) {
        summary = Map<String, dynamic>.from(snapshot.value as Map);
      }

      // Update daily consumption
      summary['total_energy_today'] =
          (summary['total_energy_today'] ?? 0.0) + consumption;
      summary['last_update'] = now.toIso8601String();

      // Update weekly and monthly (simplified - in real app, you'd calculate properly)
      summary['total_energy_week'] =
          (summary['total_energy_week'] ?? 0.0) + consumption;
      summary['total_energy_month'] =
          (summary['total_energy_month'] ?? 0.0) + consumption;

      await summaryRef.set(summary);
    } catch (e) {
      debugPrint('Error updating usage summary: $e');
    }
  }

  /// Save notification to Firestore
  Future<void> _saveNotification(
    String title,
    String message,
    String type,
  ) async {
    try {
      if (!_isAuthenticated) return;

      await _firestore.collection(_notificationsCollection).add({
        'userId': _currentUserId,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving notification: $e');
    }
  }

  /// Clear local cache
  void clearCache() {
    _currentGoals = null;
    _meterReadings.clear();
    _userType = null;
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
