import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/appliance_usage_model.dart';
import '../utils/app_logger.dart';

/// Service for managing appliance usage data in Firestore
class ApplianceUsageService {
  static final ApplianceUsageService _instance =
      ApplianceUsageService._internal();
  factory ApplianceUsageService() => _instance;
  ApplianceUsageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _usageCollection {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(_userId!)
        .collection('appliance_usage');
  }

  /// Save appliance usage data
  Future<bool> saveApplianceUsage(ApplianceUsageModel usage) async {
    if (_userId == null) {
      AppLogger.w('[ApplianceUsageService] User not authenticated');
      return false;
    }

    try {
      final usageId = usage.id.isEmpty ? _uuid.v4() : usage.id;
      await _usageCollection.doc(usageId).set(usage.toMap());

      AppLogger.i(
        '[ApplianceUsageService] ✅ Saved usage: ${usage.applianceName} - ${usage.action}',
      );
      return true;
    } catch (e) {
      AppLogger.e('[ApplianceUsageService] ❌ Error saving usage: $e');
      return false;
    }
  }

  /// Save turn_on event
  Future<bool> saveTurnOnEvent({
    required String applianceId,
    required String applianceName,
    required String applianceIcon,
    required double ratePerKwh,
    int? watts,
  }) async {
    if (_userId == null) return false;

    try {
      final usage = ApplianceUsageModel.turnOn(
        applianceId: applianceId,
        applianceName: applianceName,
        applianceIcon: applianceIcon,
        userId: _userId!,
        ratePerKwh: ratePerKwh,
        watts: watts,
      );

      return await saveApplianceUsage(usage);
    } catch (e) {
      AppLogger.e('[ApplianceUsageService] ❌ Error saving turn_on event: $e');
      return false;
    }
  }

  /// Save turn_off event with calculated metrics
  Future<bool> saveTurnOffEvent({
    required String applianceId,
    required String applianceName,
    required String applianceIcon,
    required double ratePerKwh,
    required int watts,
    required int durationSeconds,
    required DateTime sessionStartTime,
  }) async {
    if (_userId == null) return false;

    try {
      final usage = ApplianceUsageModel.turnOff(
        applianceId: applianceId,
        applianceName: applianceName,
        applianceIcon: applianceIcon,
        userId: _userId!,
        ratePerKwh: ratePerKwh,
        watts: watts,
        durationSeconds: durationSeconds,
        sessionStartTime: Timestamp.fromDate(sessionStartTime),
      );

      return await saveApplianceUsage(usage);
    } catch (e) {
      AppLogger.e('[ApplianceUsageService] ❌ Error saving turn_off event: $e');
      return false;
    }
  }

  /// Get appliance usage history
  Future<List<ApplianceUsageModel>> getApplianceUsageHistory({
    int limit = 50,
    String? applianceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_userId == null) return [];

    try {
      Query query = _usageCollection
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (applianceId != null) {
        query = query.where('applianceId', isEqualTo: applianceId);
      }

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => ApplianceUsageModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.e('[ApplianceUsageService] ❌ Error getting usage history: $e');
      return [];
    }
  }

  /// Get usage data by date range
  Future<List<ApplianceUsageModel>> getUsageByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? applianceId,
  }) async {
    if (_userId == null) return [];

    try {
      Query query = _usageCollection
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: false);

      if (applianceId != null) {
        query = query.where('applianceId', isEqualTo: applianceId);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => ApplianceUsageModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.e(
        '[ApplianceUsageService] ❌ Error getting usage by date range: $e',
      );
      return [];
    }
  }

  /// Get usage data by appliance
  Future<List<ApplianceUsageModel>> getUsageByAppliance({
    required String applianceId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_userId == null) return [];

    try {
      Query query = _usageCollection
          .where('applianceId', isEqualTo: applianceId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => ApplianceUsageModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.e(
        '[ApplianceUsageService] ❌ Error getting usage by appliance: $e',
      );
      return [];
    }
  }

  /// Get aggregated usage by date
  Future<Map<String, Map<String, double>>> getAggregatedUsageByDate({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return {};

    try {
      final usage = await getUsageByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      // Filter only turn_off events (they have actual usage data)
      final turnOffEvents = usage.where((u) => u.action == 'turn_off').toList();

      // Aggregate by date
      final Map<String, Map<String, double>> aggregated = {};

      for (final event in turnOffEvents) {
        if (!aggregated.containsKey(event.date)) {
          aggregated[event.date] = {'totalCost': 0.0, 'totalKwh': 0.0};
        }

        aggregated[event.date]!['totalCost'] =
            (aggregated[event.date]!['totalCost'] ?? 0.0) + event.cost;
        aggregated[event.date]!['totalKwh'] =
            (aggregated[event.date]!['totalKwh'] ?? 0.0) + event.kwh;
      }

      return aggregated;
    } catch (e) {
      AppLogger.e(
        '[ApplianceUsageService] ❌ Error getting aggregated usage: $e',
      );
      return {};
    }
  }

  /// Get aggregated usage by appliance
  Future<Map<String, Map<String, double>>> getAggregatedUsageByAppliance({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_userId == null) return {};

    try {
      final usage = await getApplianceUsageHistory(
        limit: 1000,
        startDate: startDate,
        endDate: endDate,
      );

      // Filter only turn_off events (they have actual usage data)
      final turnOffEvents = usage.where((u) => u.action == 'turn_off').toList();

      // Aggregate by appliance
      final Map<String, Map<String, double>> aggregated = {};

      for (final event in turnOffEvents) {
        if (!aggregated.containsKey(event.applianceId)) {
          aggregated[event.applianceId] = {
            'totalCost': 0.0,
            'totalKwh': 0.0,
            'totalDuration': 0.0,
          };
        }

        aggregated[event.applianceId]!['totalCost'] =
            (aggregated[event.applianceId]!['totalCost'] ?? 0.0) + event.cost;
        aggregated[event.applianceId]!['totalKwh'] =
            (aggregated[event.applianceId]!['totalKwh'] ?? 0.0) + event.kwh;
        aggregated[event.applianceId]!['totalDuration'] =
            (aggregated[event.applianceId]!['totalDuration'] ?? 0.0) +
            event.duration;
      }

      return aggregated;
    } catch (e) {
      AppLogger.e(
        '[ApplianceUsageService] ❌ Error getting aggregated usage by appliance: $e',
      );
      return {};
    }
  }
}
