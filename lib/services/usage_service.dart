import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appliance_model.dart';
import '../utils/app_logger.dart';

/// Service for managing usage calculations and aggregations
class UsageService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _thisMonthTimer;
  Timer? _dailyMirrorTimer;
  Timer? _todayRealtimeTimer;
  DateTime? _monthComputedFor;
  double _monthBaseKwh = 0.0;
  int _monthBaseUsageTime = 0;
  int _monthTick = 0;

  DatabaseReference get _userRef =>
      _database.ref('users/${_auth.currentUser?.uid}');
  DatabaseReference get _todayUsageRef => _userRef.child('todayUsage');
  DatabaseReference get _appliancesRef => _userRef.child('appliances');
  DatabaseReference get _thisMonthRef => _userRef.child('thisMonthUsage');

  /// Calculate device consumption for a specific appliance
  Map<String, dynamic> computeDeviceConsumption(ApplianceModel appliance) {
    final watts = appliance.watts ?? 0;
    final totalUsageTime = appliance.totalUsageTime ?? 0;
    final hoursUsed = totalUsageTime / 3600.0;
    final kwh = (watts * hoursUsed) / 1000.0;

    return {
      'kwh': kwh,
      'hoursUsed': hoursUsed,
      'watts': watts,
      'totalUsageTime': totalUsageTime,
    };
  }

  /// Start 1s updater for RTDB todayUsage using live appliance computation
  void startTodayRealtimeUpdater() {
    _todayRealtimeTimer?.cancel();
    _todayRealtimeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;

        final now = DateTime.now();
        final todayKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // Read appliances and compute live kWh (base + live for ON devices)
        // Always read fresh from database to ensure we get latest cumulative values
        final appliances = await _appliancesRef.get();
        double totalKwh = 0.0;
        int totalUsageTime = 0; // kept from legacy; not computed live here

        if (appliances.value != null) {
          final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
            appliances.value as Map,
          );
          final nowTs = DateTime.now();
          for (final entry in data.entries) {
            final applianceData = Map<String, dynamic>.from(entry.value as Map);
            // Always use cumulative kwh value (this includes all past sessions)
            final baseKwh = (applianceData['kwh'] ?? 0.0).toDouble();
            totalKwh += baseKwh;

            // Add live kWh only for appliances that are currently ON
            // (these haven't been added to cumulative kwh yet)
            final bool isOn = applianceData['isOn'] == true;
            final String? startTimeStr = applianceData['startTime'] as String?;
            final num wattsNum = (applianceData['watts'] ?? 0) as num;
            final int watts = wattsNum.toInt();
            if (isOn &&
                startTimeStr != null &&
                startTimeStr.isNotEmpty &&
                watts > 0) {
              final startTime = DateTime.tryParse(startTimeStr);
              if (startTime != null) {
                final seconds = nowTs.difference(startTime).inSeconds;
                if (seconds > 0) {
                  final hours = seconds / 3600.0;
                  final liveKwh = (watts * hours) / 1000.0;
                  totalKwh += liveKwh;
                }
              }
            }
          }
        }

        final rate = await _getCurrentPowerRate();
        final totalCost = totalKwh * rate;

        // Only update if the calculated value is valid (non-negative)
        // This prevents overwriting with incorrect values during race conditions
        if (totalKwh >= 0 && totalCost >= 0) {
          await _todayUsageRef.set({
            'totalKwh': totalKwh,
            'totalCost': totalCost,
            'totalUsageTime': totalUsageTime,
            'date': todayKey,
            'lastUpdated': now.toIso8601String(),
          });
        }
      } catch (e) {
        AppLogger.i('[UsageService] Today realtime updater error: $e');
      }
    });
  }

  /// Roll up today's usage from all appliances
  Future<Map<String, dynamic>> rollUpTodayUsage() async {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Get current power rate
    final rate = await _getCurrentPowerRate();

    // Calculate totals from all appliances
    final appliances = await _appliancesRef.get();
    double totalKwh = 0.0;
    int totalUsageTime = 0;

    if (appliances.value != null) {
      final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
        appliances.value as Map,
      );
      for (final entry in data.entries) {
        final applianceData = Map<String, dynamic>.from(entry.value as Map);
        totalKwh += (applianceData['kwh'] ?? 0.0).toDouble();
        totalUsageTime += (applianceData['totalUsageTime'] ?? 0) as int;
      }
    }

    final totalCost = totalKwh * rate;

    // Update today's usage in Realtime DB
    await _todayUsageRef.set({
      'totalKwh': totalKwh,
      'totalCost': totalCost,
      'totalUsageTime': totalUsageTime,
      'date': todayKey,
      'lastUpdated': now.toIso8601String(),
    });

    return {
      'totalKwh': totalKwh,
      'totalCost': totalCost,
      'totalUsageTime': totalUsageTime,
      'rate': rate,
      'date': todayKey,
    };
  }

  /// Stream of today's usage with real-time updates
  Stream<Map<String, dynamic>> listenToTodayUsage() {
    return _todayUsageRef.onValue
        .map((event) async {
          if (event.snapshot.value == null) {
            return await rollUpTodayUsage();
          }

          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final rate = await _getCurrentPowerRate();

          // Recalculate cost with current rate
          final totalKwh = (data['totalKwh'] ?? 0.0).toDouble();
          final totalCost = totalKwh * rate;

          return {
            'totalKwh': totalKwh,
            'totalCost': totalCost,
            'totalUsageTime': data['totalUsageTime'] ?? 0,
            'rate': rate,
            'date': data['date'] ?? '',
            'lastUpdated': data['lastUpdated'] ?? '',
          };
        })
        .asyncMap((event) => event);
  }

  /// Calculate this month's usage from Firestore trends
  Future<Map<String, dynamic>> getThisMonthUsage() async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    try {
      final doc =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .collection('energy_trends')
              .doc('monthly')
              .collection('data')
              .doc(monthKey)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        final totalKwh = (data['totalKwh'] ?? 0.0).toDouble();

        // Recalculate cost with current power rate
        final currentRate = await _getCurrentPowerRate();
        final totalCost = totalKwh * currentRate;

        return {
          'totalKwh': totalKwh,
          'totalCost': totalCost,
          'totalUsageTime': data['totalUsageTime'] ?? 0,
          'month': monthKey,
        };
      }
    } catch (e) {
      AppLogger.i('[UsageService] Error getting monthly usage: $e');
    }

    return {
      'totalKwh': 0.0,
      'totalCost': 0.0,
      'totalUsageTime': 0,
      'month': monthKey,
    };
  }

  /// Stream of this month's usage
  Stream<Map<String, dynamic>> listenToThisMonthUsage() {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));

    // Primary: stream from pre-aggregated monthly doc if present
    final monthlyDocStream =
        _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .collection('energy_trends')
            .doc('monthly')
            .collection('data')
            .doc(monthKey)
            .snapshots();

    // Fallback: aggregate from appliance_usage turn_off events within month
    final usageQueryStream =
        _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .collection('appliance_usage')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
            )
            .where('action', isEqualTo: 'turn_off')
            .snapshots();

    return monthlyDocStream.asyncMap((snapshot) async {
      double totalKwh = 0.0;
      int totalUsageTime = 0;

      if (snapshot.exists) {
        final data = snapshot.data()!;
        totalKwh = (data['totalKwh'] ?? 0.0).toDouble();
        totalUsageTime = (data['totalUsageTime'] ?? 0) as int;
      } else {
        // Use fallback aggregation from raw events
        final events = await usageQueryStream.first;
        for (final doc in events.docs) {
          final data = doc.data();
          totalKwh += (data['kwh'] ?? 0.0).toDouble();
          totalUsageTime += (data['duration'] ?? 0) as int;
        }
      }

      final currentRate = await _getCurrentPowerRate();
      final totalCost = totalKwh * currentRate;

      return {
        'totalKwh': totalKwh,
        'totalCost': totalCost,
        'totalUsageTime': totalUsageTime,
        'month': monthKey,
        'rate': currentRate,
      };
    });
  }

  /// Real-time monthly updater (1s): writes to RTDB `thisMonthUsage`
  void startMonthlyRealtimeUpdater() {
    _thisMonthTimer?.cancel();
    _monthTick = 0;
    _thisMonthTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final forceWrite = _monthTick % 20 == 0;
        await _performMonthlyUpdate(forceFirestoreWrite: forceWrite);

        _monthTick++;
      } catch (e) {
        AppLogger.i('[UsageService] Monthly updater error: $e');
      }
    });
  }

  /// Listen to RTDB monthly node for instant UI
  Stream<Map<String, dynamic>> listenToThisMonthUsageRTDB() {
    return _thisMonthRef.onValue.map((event) {
      if (event.snapshot.value == null) {
        return {
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'totalUsageTime': 0,
          'month': _currentMonthKey(),
        };
      }
      final map = Map<String, dynamic>.from(event.snapshot.value as Map);
      return {
        'totalKwh': (map['totalKwh'] ?? 0.0).toDouble(),
        'totalCost': (map['totalCost'] ?? 0.0).toDouble(),
        'totalUsageTime': (map['totalUsageTime'] ?? 0) as int,
        'month': (map['month'] ?? _currentMonthKey()) as String,
      };
    });
  }

  /// Listen to Firestore monthly collection for persistent month-to-date totals
  Stream<Map<String, dynamic>> listenToThisMonthUsageFirestore() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value({
        'totalKwh': 0.0,
        'totalCost': 0.0,
        'totalUsageTime': 0,
        'month': _currentMonthKey(),
      });
    }

    final monthKey = _currentMonthKey();
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('energy_trends')
        .doc('monthly')
        .collection('data')
        .doc(monthKey);

    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return {
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'totalUsageTime': 0,
          'month': monthKey,
        };
      }
      final data = snapshot.data()!;
      return {
        'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
        'totalCost': (data['totalCost'] ?? 0.0).toDouble(),
        'totalUsageTime': (data['totalUsageTime'] ?? 0) as int,
        'month': (data['month'] ?? monthKey) as String,
      };
    });
  }

  /// Force a monthly sync (used after appliance state changes)
  Future<void> syncMonthlyTotals() async {
    await _performMonthlyUpdate(forceFirestoreWrite: true);
  }

  Future<void> _performMonthlyUpdate({bool forceFirestoreWrite = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Refresh monthly base periodically or when month changes
    final shouldRefreshBase =
        _monthComputedFor == null ||
        _monthComputedFor!.year != now.year ||
        _monthComputedFor!.month != now.month ||
        _monthTick % 30 == 0 ||
        forceFirestoreWrite;

    if (shouldRefreshBase) {
      await _refreshMonthlyBase(now);
      _monthComputedFor = now;
    }

    // Read today's live totals from RTDB
    final todaySnap = await _todayUsageRef.get();
    double todayKwh = 0.0;
    int todayUsageTime = 0;
    if (todaySnap.exists && todaySnap.value != null) {
      final map = Map<String, dynamic>.from(todaySnap.value as Map);
      todayKwh = (map['totalKwh'] ?? 0.0).toDouble();
      todayUsageTime = (map['totalUsageTime'] ?? 0) as int;
    }

    // Combine base totals (previous days) with today's live totals
    final totalKwh = _monthBaseKwh + todayKwh;
    final totalUsageTime = _monthBaseUsageTime + todayUsageTime;
    final rate = await _getCurrentPowerRate();
    final totalCost = totalKwh * rate;

    // Write to RTDB for live UI
    await _thisMonthRef.set({
      'totalKwh': totalKwh,
      'totalCost': totalCost,
      'totalUsageTime': totalUsageTime,
      'month': monthKey,
      'lastUpdated': now.toIso8601String(),
    });

    // Persist to Firestore when requested or on throttle interval
    if (forceFirestoreWrite) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('energy_trends')
          .doc('monthly')
          .collection('data')
          .doc(monthKey)
          .set({
            'month': monthKey,
            'totalKwh': totalKwh,
            'totalCost': totalCost,
            'totalUsageTime': totalUsageTime,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }
  }

  /// Helper: recompute monthly base (all turn_off events from start of month, excluding today's RTDB live contribution)
  Future<void> _refreshMonthlyBase(DateTime now) async {
    try {
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(milliseconds: 1));
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      double sumKwh = 0.0;
      int sumUsage = 0;

      final snapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('appliance_usage')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
              )
              .where('action', isEqualTo: 'turn_off')
              .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        sumKwh += (data['kwh'] ?? 0.0).toDouble();
        sumUsage += (data['duration'] ?? 0) as int;
      }

      _monthBaseKwh = sumKwh;
      _monthBaseUsageTime = sumUsage;
    } catch (e) {
      AppLogger.i('[UsageService] Error refreshing monthly base: $e');
    }
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Start daily realtime mirror to Firestore (throttled ~15s)
  void startDailyRealtimeMirror() {
    _dailyMirrorTimer?.cancel();
    _dailyMirrorTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;

        final now = DateTime.now();
        final todayKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // Read RTDB todayUsage
        final todaySnap = await _todayUsageRef.get();
        double totalKwh = 0.0;
        int totalUsageTime = 0;
        if (todaySnap.exists && todaySnap.value != null) {
          final map = Map<String, dynamic>.from(todaySnap.value as Map);
          totalKwh = (map['totalKwh'] ?? 0.0).toDouble();
          totalUsageTime = (map['totalUsageTime'] ?? 0) as int;
        }

        // Recalculate cost with current power rate
        final rate = await _getCurrentPowerRate();
        final totalCost = totalKwh * rate;

        // Persist to Firestore daily trends (merge)
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('energy_trends')
            .doc('daily')
            .collection('data')
            .doc(todayKey)
            .set({
              'date': todayKey,
              'totalKwh': totalKwh,
              'totalCost': totalCost,
              'totalUsageTime': totalUsageTime,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        AppLogger.i('[UsageService] Daily mirror error: $e');
      }
    });
  }

  /// Roll up today's usage into Firestore daily trends and reset RTDB if date changed
  Future<void> rollUpTodayUsageToFirestoreIfNeeded() async {
    try {
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final todaySnap = await _todayUsageRef.get();
      Map<String, dynamic> today = {};
      if (todaySnap.exists && todaySnap.value != null) {
        today = Map<String, dynamic>.from(todaySnap.value as Map);
      }

      final currentDateKey = (today['date'] ?? '') as String;
      if (currentDateKey == todayKey) {
        return; // same day, nothing to roll up
      }

      final rate = await _getCurrentPowerRate();
      final totalKwh = (today['totalKwh'] ?? 0.0).toDouble();
      final totalCost = totalKwh * rate;
      final totalUsageTime = (today['totalUsageTime'] ?? 0) as int;
      final prevDate = currentDateKey.isEmpty ? todayKey : currentDateKey;

      // Write to daily trends
      await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .collection('energy_trends')
          .doc('daily')
          .collection('data')
          .doc(prevDate)
          .set({
            'date': prevDate,
            'totalKwh': totalKwh,
            'totalCost': totalCost,
            'totalUsageTime': totalUsageTime,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Reset RTDB for new day
      await resetDailyUsage();
    } catch (e) {
      AppLogger.i('[UsageService] Error rolling up daily usage: $e');
    }
  }

  /// Get current power rate from Firestore admin_settings/system_config/powerRate
  Future<double> _getCurrentPowerRate() async {
    try {
      final doc =
          await _firestore
              .collection('admin_settings')
              .doc('system_config')
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data['powerRate'] != null) {
          return (data['powerRate'] as num).toDouble();
        }
      }
    } catch (e) {
      AppLogger.i('[UsageService] Error getting power rate: $e');
    }

    return 12.50; // Default rate
  }

  /// Stream of current power rate
  Stream<double> listenToCurrentPowerRate() {
    return _firestore
        .collection('admin_settings')
        .doc('system_config')
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            if (data['powerRate'] != null) {
              return (data['powerRate'] as num).toDouble();
            }
          }
          return 12.50; // Default rate
        });
  }

  /// Calculate predicted monthly cost based on current usage
  Future<double> calculatePredictedMonthlyCost() async {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;

    final todayUsage = await _getTodayUsageData();
    final dailyAverage = todayUsage['totalKwh'] / currentDay;
    final predictedMonthlyKwh = dailyAverage * daysInMonth;

    final rate = await _getCurrentPowerRate();
    return predictedMonthlyKwh * rate;
  }

  /// Get today's usage data
  Future<Map<String, dynamic>> _getTodayUsageData() async {
    final snapshot = await _todayUsageRef.get();
    if (!snapshot.exists) {
      return {'totalKwh': 0.0, 'totalCost': 0.0, 'totalUsageTime': 0};
    }
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  /// Reset daily usage (called at midnight)
  Future<void> resetDailyUsage() async {
    await _todayUsageRef.set({
      'totalKwh': 0.0,
      'totalCost': 0.0,
      'totalUsageTime': 0,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  /// Get usage statistics for a date range
  Future<Map<String, dynamic>> getUsageStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startKey =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endKey =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .collection('energy_trends')
              .doc('daily')
              .collection('data')
              .where('date', isGreaterThanOrEqualTo: startKey)
              .where('date', isLessThanOrEqualTo: endKey)
              .get();

      double totalKwh = 0.0;
      double totalCost = 0.0;
      int totalUsageTime = 0;
      int dayCount = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        totalKwh += (data['totalKwh'] ?? 0.0).toDouble();
        totalCost += (data['totalCost'] ?? 0.0).toDouble();
        totalUsageTime += (data['totalUsageTime'] ?? 0) as int;
        dayCount++;
      }

      return {
        'totalKwh': totalKwh,
        'totalCost': totalCost,
        'totalUsageTime': totalUsageTime,
        'averageDailyKwh': dayCount > 0 ? totalKwh / dayCount : 0.0,
        'averageDailyCost': dayCount > 0 ? totalCost / dayCount : 0.0,
        'dayCount': dayCount,
        'startDate': startKey,
        'endDate': endKey,
      };
    } catch (e) {
      AppLogger.i('[UsageService] Error getting usage stats: $e');
      return {
        'totalKwh': 0.0,
        'totalCost': 0.0,
        'totalUsageTime': 0,
        'averageDailyKwh': 0.0,
        'averageDailyCost': 0.0,
        'dayCount': 0,
        'startDate': startKey,
        'endDate': endKey,
      };
    }
  }
}
