import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Service for managing recent activity logs
class RecentActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';
  CollectionReference get _activitiesRef =>
      _firestore.collection('users').doc(_userId).collection('recent_activity');

  /// Add a new activity
  Future<void> addActivity({
    required String type,
    required String message,
    Map<String, dynamic>? meta,
  }) async {
    try {
      await _activitiesRef.add({
        'type': type,
        'message': message,
        'meta': meta ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _userId,
      });
    } catch (e) {
      AppLogger.i('[RecentActivityService] Error adding activity: $e');
      throw Exception('Failed to add activity: $e');
    }
  }

  /// Add appliance activity
  Future<void> addApplianceActivity({
    required String applianceName,
    required bool isOn,
    required String applianceId,
    String? applianceIcon,
    double? cost,
    double? kwh,
  }) async {
    final type = isOn ? 'appliance_on' : 'appliance_off';
    final message =
        isOn ? '$applianceName turned ON' : '$applianceName turned OFF';

    final meta = {
      'applianceId': applianceId,
      'applianceName': applianceName,
      if (applianceIcon != null) 'applianceIcon': applianceIcon,
      'isOn': isOn,
      'cost': cost,
      'kwh': kwh,
    };

    await addActivity(type: type, message: message, meta: meta);
  }

  /// Add energy threshold activity
  Future<void> addThresholdActivity({
    required String thresholdType,
    required double currentValue,
    required double thresholdValue,
    required double targetValue,
  }) async {
    final percentage = (currentValue / targetValue * 100).toStringAsFixed(1);
    final message = 'Energy ${thresholdType} reached ${percentage}% of target';

    final meta = {
      'thresholdType': thresholdType,
      'currentValue': currentValue,
      'thresholdValue': thresholdValue,
      'targetValue': targetValue,
      'percentage': double.parse(percentage),
    };

    await addActivity(type: 'threshold_reached', message: message, meta: meta);
  }

  /// Add goal achievement activity
  Future<void> addGoalAchievementActivity({
    required String achievementType,
    required String message,
    Map<String, dynamic>? meta,
  }) async {
    await addActivity(type: 'goal_achieved', message: message, meta: meta);
  }

  /// Add daily summary activity
  Future<void> addDailySummaryActivity({
    required double totalCost,
    required double totalKwh,
    required double targetCost,
    required double targetKwh,
  }) async {
    final costPercentage = (totalCost / targetCost * 100).toStringAsFixed(1);
    final kwhPercentage = (totalKwh / targetKwh * 100).toStringAsFixed(1);

    String message;
    if (totalCost <= targetCost * 0.8) {
      message =
          'Great day! Used ₱${totalCost.toStringAsFixed(2)} (${costPercentage}% of target)';
    } else if (totalCost <= targetCost) {
      message =
          'Good progress! Used ₱${totalCost.toStringAsFixed(2)} (${costPercentage}% of target)';
    } else {
      message =
          'Exceeded target by ₱${(totalCost - targetCost).toStringAsFixed(2)}';
    }

    final meta = {
      'totalCost': totalCost,
      'totalKwh': totalKwh,
      'targetCost': targetCost,
      'targetKwh': targetKwh,
      'costPercentage': double.parse(costPercentage),
      'kwhPercentage': double.parse(kwhPercentage),
    };

    await addActivity(type: 'daily_summary', message: message, meta: meta);
  }

  /// Stream of recent activities
  Stream<List<Map<String, dynamic>>> listenRecentActivities({int limit = 10}) {
    return _activitiesRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'type': data['type'] ?? '',
              'message': data['message'] ?? '',
              'meta': data['meta'] ?? {},
              'timestamp': data['timestamp'],
              'userId': data['userId'] ?? '',
            };
          }).toList();
        });
  }

  /// Get recent activities
  Future<List<Map<String, dynamic>>> getRecentActivities({
    int limit = 10,
  }) async {
    try {
      final query =
          await _activitiesRef
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'type': data['type'] ?? '',
          'message': data['message'] ?? '',
          'meta': data['meta'] ?? {},
          'timestamp': data['timestamp'],
          'userId': data['userId'] ?? '',
        };
      }).toList();
    } catch (e) {
      AppLogger.i(
        '[RecentActivityService] Error getting recent activities: $e',
      );
      return [];
    }
  }

  /// Get activities by type
  Future<List<Map<String, dynamic>>> getActivitiesByType(
    String type, {
    int limit = 20,
  }) async {
    try {
      final query =
          await _activitiesRef
              .where('type', isEqualTo: type)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'type': data['type'] ?? '',
          'message': data['message'] ?? '',
          'meta': data['meta'] ?? {},
          'timestamp': data['timestamp'],
          'userId': data['userId'] ?? '',
        };
      }).toList();
    } catch (e) {
      AppLogger.i(
        '[RecentActivityService] Error getting activities by type: $e',
      );
      return [];
    }
  }

  /// Get activity statistics
  Future<Map<String, dynamic>> getActivityStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Get today's activities
      final todayQuery =
          await _activitiesRef
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .get();

      // Get this week's activities
      final weekQuery =
          await _activitiesRef
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
              )
              .get();

      // Get this month's activities
      final monthQuery =
          await _activitiesRef
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
              )
              .get();

      // Count activities by type
      final todayActivities = _countActivitiesByType(todayQuery.docs);
      final weekActivities = _countActivitiesByType(weekQuery.docs);
      final monthActivities = _countActivitiesByType(monthQuery.docs);

      return {
        'today': {'total': todayQuery.docs.length, 'byType': todayActivities},
        'week': {'total': weekQuery.docs.length, 'byType': weekActivities},
        'month': {'total': monthQuery.docs.length, 'byType': monthActivities},
      };
    } catch (e) {
      AppLogger.i('[RecentActivityService] Error getting activity stats: $e');
      return {
        'today': {'total': 0, 'byType': {}},
        'week': {'total': 0, 'byType': {}},
        'month': {'total': 0, 'byType': {}},
      };
    }
  }

  /// Count activities by type
  Map<String, int> _countActivitiesByType(List<QueryDocumentSnapshot> docs) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] ?? 'unknown';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  /// Clear old activities (keep last 100)
  Future<void> clearOldActivities() async {
    try {
      final query =
          await _activitiesRef
              .orderBy('timestamp', descending: true)
              .limit(1000) // Get more than we need
              .get();

      if (query.docs.length > 100) {
        final batch = _firestore.batch();
        // Delete all but the first 100
        for (int i = 100; i < query.docs.length; i++) {
          batch.delete(query.docs[i].reference);
        }
        await batch.commit();
      }
    } catch (e) {
      AppLogger.i('[RecentActivityService] Error clearing old activities: $e');
    }
  }

  /// Delete specific activity
  Future<void> deleteActivity(String activityId) async {
    try {
      await _activitiesRef.doc(activityId).delete();
    } catch (e) {
      AppLogger.i('[RecentActivityService] Error deleting activity: $e');
      throw Exception('Failed to delete activity: $e');
    }
  }

  /// Get activity icon based on type
  String getActivityIcon(String type) {
    switch (type) {
      case 'appliance_on':
        return '🔌';
      case 'appliance_off':
        return '🔌';
      case 'threshold_reached':
        return '⚠️';
      case 'goal_achieved':
        return '🎉';
      case 'daily_summary':
        return '📊';
      case 'energy_alert':
        return '⚡';
      case 'cost_alert':
        return '💰';
      default:
        return '📝';
    }
  }

  /// Get activity color based on type
  String getActivityColor(String type) {
    switch (type) {
      case 'appliance_on':
        return '#27AE60'; // Green
      case 'appliance_off':
        return '#E74C3C'; // Red
      case 'threshold_reached':
        return '#F39C12'; // Orange
      case 'goal_achieved':
        return '#3498DB'; // Blue
      case 'daily_summary':
        return '#9B59B6'; // Purple
      case 'energy_alert':
        return '#E67E22'; // Dark Orange
      case 'cost_alert':
        return '#E74C3C'; // Red
      default:
        return '#95A5A6'; // Gray
    }
  }
}
