import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/app_logger.dart';

/// Service for monitoring energy usage and rates
class MonitoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String get _userId => _auth.currentUser?.uid ?? '';
  DocumentReference get _currentRateRef =>
      _firestore.collection('admin_settings').doc('system_config');
  DatabaseReference get _todayUsageRef =>
      _database.ref('users/$_userId/todayUsage');
  DocumentReference get _estimatedBillsRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('estimatedBills')
      .doc('latest');

  /// Get current power rate from admin_settings/system_config/powerRate
  Future<double> getCurrentRate() async {
    try {
      final doc = await _currentRateRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['powerRate'] != null) {
          return (data['powerRate'] as num).toDouble();
        }
      }
    } catch (e) {
      AppLogger.i('[MonitoringService] Error getting current rate: $e');
    }
    return 12.50; // Default rate
  }

  /// Stream of current power rate
  Stream<double> listenToCurrentRate() {
    return _currentRateRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['powerRate'] != null) {
          return (data['powerRate'] as num).toDouble();
        }
      }
      return 12.50; // Default rate
    });
  }

  /// Get current rate with metadata
  Future<Map<String, dynamic>> getCurrentRateWithMetadata() async {
    try {
      final doc = await _currentRateRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'rate_per_kwh': (data['powerRate'] ?? 12.50).toDouble(),
          'last_updated': data['updatedAt'],
          'updated_by': data['updatedBy'] ?? 'system',
          'currency': 'PHP',
          'unit': 'kWh',
        };
      }
    } catch (e) {
      AppLogger.i(
        '[MonitoringService] Error getting current rate metadata: $e',
      );
    }
    return {
      'rate_per_kwh': 12.50,
      'last_updated': null,
      'updated_by': 'system',
      'currency': 'PHP',
      'unit': 'kWh',
    };
  }

  /// Get today's usage from Realtime DB
  Future<Map<String, dynamic>> getTodayUsage() async {
    try {
      final snapshot = await _todayUsageRef.get();
      if (!snapshot.exists) {
        return {
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'totalUsageTime': 0,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
      }
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      AppLogger.i('[MonitoringService] Error getting today usage: $e');
      return {
        'totalKwh': 0.0,
        'totalCost': 0.0,
        'totalUsageTime': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Stream of today's usage
  Stream<Map<String, dynamic>> listenToTodayUsage() {
    return _todayUsageRef.onValue.map((event) {
      if (event.snapshot.value == null) {
        return {
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'totalUsageTime': 0,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  /// Get estimated bill from Firestore
  Future<Map<String, dynamic>> getEstimatedBill() async {
    try {
      final doc = await _estimatedBillsRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'estimatedCost': (data['estimatedCost'] ?? 0.0).toDouble(),
          'estimatedKwh': (data['estimatedKwh'] ?? 0.0).toDouble(),
          'calculationDate': data['calculationDate'],
          'method': data['method'] ?? 'usage_based',
        };
      }
    } catch (e) {
      AppLogger.i('[MonitoringService] Error getting estimated bill: $e');
    }
    return {
      'estimatedCost': 0.0,
      'estimatedKwh': 0.0,
      'calculationDate': null,
      'method': 'usage_based',
    };
  }

  /// Stream of estimated bill
  Stream<Map<String, dynamic>> listenToEstimatedBill() {
    return _estimatedBillsRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return {
          'estimatedCost': (data['estimatedCost'] ?? 0.0).toDouble(),
          'estimatedKwh': (data['estimatedKwh'] ?? 0.0).toDouble(),
          'calculationDate': data['calculationDate'],
          'method': data['method'] ?? 'usage_based',
        };
      }
      return {
        'estimatedCost': 0.0,
        'estimatedKwh': 0.0,
        'calculationDate': null,
        'method': 'usage_based',
      };
    });
  }

  /// Calculate estimated monthly bill based on current usage
  Future<Map<String, dynamic>> calculateEstimatedMonthlyBill() async {
    try {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final currentDay = now.day;

      final todayUsage = await getTodayUsage();
      final currentRate = await getCurrentRate();

      final dailyAverageKwh = (todayUsage['totalKwh'] ?? 0.0) / currentDay;
      final estimatedMonthlyKwh = dailyAverageKwh * daysInMonth;
      final estimatedMonthlyCost = estimatedMonthlyKwh * currentRate;

      // Save estimated bill to Firestore
      await _estimatedBillsRef.set({
        'estimatedCost': estimatedMonthlyCost,
        'estimatedKwh': estimatedMonthlyKwh,
        'calculationDate': FieldValue.serverTimestamp(),
        'method': 'usage_based',
        'dailyAverage': dailyAverageKwh,
        'currentRate': currentRate,
      });

      return {
        'estimatedCost': estimatedMonthlyCost,
        'estimatedKwh': estimatedMonthlyKwh,
        'dailyAverage': dailyAverageKwh,
        'currentRate': currentRate,
        'calculationDate': now,
      };
    } catch (e) {
      AppLogger.i(
        '[MonitoringService] Error calculating estimated monthly bill: $e',
      );
      return {
        'estimatedCost': 0.0,
        'estimatedKwh': 0.0,
        'dailyAverage': 0.0,
        'currentRate': 12.50,
        'calculationDate': DateTime.now(),
      };
    }
  }

  /// Get monitoring dashboard data
  Future<Map<String, dynamic>> getMonitoringDashboard() async {
    try {
      final currentRate = await getCurrentRate();
      final todayUsage = await getTodayUsage();
      final estimatedBill = await getEstimatedBill();

      return {
        'currentRate': currentRate,
        'todayUsage': todayUsage,
        'estimatedBill': estimatedBill,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.i('[MonitoringService] Error getting monitoring dashboard: $e');
      return {
        'currentRate': 12.50,
        'todayUsage': {'totalKwh': 0.0, 'totalCost': 0.0, 'totalUsageTime': 0},
        'estimatedBill': {'estimatedCost': 0.0, 'estimatedKwh': 0.0},
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Stream of monitoring dashboard data
  Stream<Map<String, dynamic>> listenToMonitoringDashboard() {
    return listenToCurrentRate().asyncMap((currentRate) async {
      final todayUsage = await getTodayUsage();
      final estimatedBill = await getEstimatedBill();

      return {
        'currentRate': currentRate,
        'todayUsage': todayUsage,
        'estimatedBill': estimatedBill,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    });
  }

  /// Format currency with proper formatting
  String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  /// Format kWh with proper formatting
  String formatKwh(double kwh) {
    return '${kwh.toStringAsFixed(2)} kWh';
  }

  /// Format usage time
  String formatUsageTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  /// Get rate history for monitoring
  Future<List<Map<String, dynamic>>> getRateHistory({int limit = 10}) async {
    try {
      final query =
          await _firestore
              .collection('admin')
              .doc('rate_history')
              .collection('rates')
              .orderBy('last_updated', descending: true)
              .limit(limit)
              .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'rate_per_kwh': (data['rate_per_kwh'] ?? 0.0).toDouble(),
          'last_updated': data['last_updated'],
          'updated_by': data['updated_by'] ?? 'system',
        };
      }).toList();
    } catch (e) {
      AppLogger.i('[MonitoringService] Error getting rate history: $e');
      return [];
    }
  }

  /// Get usage statistics for monitoring
  Future<Map<String, dynamic>> getUsageStatistics() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Get daily trends for this week
      final weekQuery =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energy_trends')
              .doc('daily')
              .collection('data')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
              )
              .get();

      // Get daily trends for this month
      final monthQuery =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energy_trends')
              .doc('daily')
              .collection('data')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
              )
              .get();

      double weekKwh = 0.0;
      double weekCost = 0.0;
      double monthKwh = 0.0;
      double monthCost = 0.0;

      for (final doc in weekQuery.docs) {
        final data = doc.data();
        weekKwh += (data['totalKwh'] ?? 0.0).toDouble();
        weekCost += (data['totalCost'] ?? 0.0).toDouble();
      }

      for (final doc in monthQuery.docs) {
        final data = doc.data();
        monthKwh += (data['totalKwh'] ?? 0.0).toDouble();
        monthCost += (data['totalCost'] ?? 0.0).toDouble();
      }

      return {
        'week': {
          'totalKwh': weekKwh,
          'totalCost': weekCost,
          'averageDailyKwh': weekKwh / 7,
          'averageDailyCost': weekCost / 7,
        },
        'month': {
          'totalKwh': monthKwh,
          'totalCost': monthCost,
          'averageDailyKwh': monthKwh / now.day,
          'averageDailyCost': monthCost / now.day,
        },
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.i('[MonitoringService] Error getting usage statistics: $e');
      return {
        'week': {
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'averageDailyKwh': 0.0,
          'averageDailyCost': 0.0,
        },
        'month': {
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'averageDailyKwh': 0.0,
          'averageDailyCost': 0.0,
        },
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }
}
