import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/app_logger.dart';
import '../services/predictive_dataset_service.dart';
import '../services/monitoring_dataset_service.dart';
import '../models/predictive_data_model.dart';

/// Service for managing energy trends and aggregations
class TrendsService {
  // Singleton pattern for persistent caching
  TrendsService._internal();
  static final TrendsService _instance = TrendsService._internal();

  /// Singleton instance - use this to ensure data persistence across navigation
  factory TrendsService() => _instance;

  /// Explicit singleton accessor
  static TrendsService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final PredictiveDatasetService _predictiveDatasetService =
      PredictiveDatasetService();

  // Persistent caches that survive widget rebuilds
  List<Map<String, dynamic>>? _dailyDataCache;
  List<Map<String, dynamic>>? _weeklyDataCache;
  List<Map<String, dynamic>>? _monthlyDataCache;
  int? _cachedYear;

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Clear all caches (useful when user changes or year changes)
  void clearCache() {
    _dailyDataCache = null;
    _weeklyDataCache = null;
    _monthlyDataCache = null;
    _cachedYear = null;
    AppLogger.i('[TrendsService] Cache cleared');
  }

  /// Clear only monthly cache (useful for real-time updates)
  void clearMonthlyCache() {
    _monthlyDataCache = null;
    AppLogger.i('[TrendsService] Monthly cache cleared');
  }

  /// Run daily aggregation from Realtime DB to Firestore
  Future<void> runDailyAggregation(DateTime date) async {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // Get today's usage from Realtime DB
      final todayUsage = await _getTodayUsageFromRealtimeDB();

      // Get current power rate
      final rate = await _getCurrentPowerRate();
      final totalCost = todayUsage['totalKwh'] * rate;

      // Save to Firestore daily trends
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('energy_trends')
          .doc('daily')
          .collection('data')
          .doc(dateKey)
          .set({
            'totalKwh': todayUsage['totalKwh'],
            'totalCost': totalCost,
            'totalUsageTime': todayUsage['totalUsageTime'],
            'date': dateKey,
            'timestamp': Timestamp.fromDate(date),
            'rate': rate,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Update weekly aggregation
      await _updateWeeklyAggregation(date);

      // Update monthly aggregation
      await _updateMonthlyAggregation(date);

      // Update monitoring dataset reference (for graphs and AI predictions)
      final monitoringDatasetService = MonitoringDatasetService();
      await monitoringDatasetService.updateDatasetReference();

      AppLogger.i('[TrendsService] Daily aggregation completed for $dateKey');
    } catch (e) {
      AppLogger.i('[TrendsService] Error in daily aggregation: $e');
      throw Exception('Failed to run daily aggregation: $e');
    }
  }

  /// Update weekly aggregation
  Future<void> _updateWeeklyAggregation(DateTime date) async {
    final weekKey = _getWeekKey(date);

    try {
      // Get all daily data for this week
      final startOfWeek = _getStartOfWeek(date);
      final endOfWeek = _getEndOfWeek(date);

      final query =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energy_trends')
              .doc('daily')
              .collection('data')
              .where('date', isGreaterThanOrEqualTo: _formatDate(startOfWeek))
              .where('date', isLessThanOrEqualTo: _formatDate(endOfWeek))
              .get();

      double totalKwh = 0.0;
      double totalCost = 0.0;
      int totalUsageTime = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        totalKwh += (data['totalKwh'] ?? 0.0).toDouble();
        totalCost += (data['totalCost'] ?? 0.0).toDouble();
        totalUsageTime += (data['totalUsageTime'] ?? 0) as int;
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('energy_trends')
          .doc('weekly')
          .collection('data')
          .doc(weekKey)
          .set({
            'totalKwh': totalKwh,
            'totalCost': totalCost,
            'totalUsageTime': totalUsageTime,
            'week': weekKey,
            'startDate': _formatDate(startOfWeek),
            'endDate': _formatDate(endOfWeek),
            'timestamp': Timestamp.fromDate(date),
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      AppLogger.i('[TrendsService] Error updating weekly aggregation: $e');
    }
  }

  /// Update monthly aggregation
  Future<void> _updateMonthlyAggregation(DateTime date) async {
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

    try {
      // Get all daily data for this month
      final startOfMonth = DateTime(date.year, date.month, 1);
      final endOfMonth = DateTime(date.year, date.month + 1, 0);

      final query =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energy_trends')
              .doc('daily')
              .collection('data')
              .where('date', isGreaterThanOrEqualTo: _formatDate(startOfMonth))
              .where('date', isLessThanOrEqualTo: _formatDate(endOfMonth))
              .get();

      double totalKwh = 0.0;
      double totalCost = 0.0;
      int totalUsageTime = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        totalKwh += (data['totalKwh'] ?? 0.0).toDouble();
        totalCost += (data['totalCost'] ?? 0.0).toDouble();
        totalUsageTime += (data['totalUsageTime'] ?? 0) as int;
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('energy_trends')
          .doc('monthly')
          .collection('data')
          .doc(monthKey)
          .set({
            'totalKwh': totalKwh,
            'totalCost': totalCost,
            'totalUsageTime': totalUsageTime,
            'month': monthKey,
            'startDate': _formatDate(startOfMonth),
            'endDate': _formatDate(endOfMonth),
            'timestamp': Timestamp.fromDate(date),
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      AppLogger.i('[TrendsService] Error updating monthly aggregation: $e');
    }
  }

  /// Get daily trends for a date range (CSV data first, then Firestore fallback)
  /// Uses persistent cache to maintain data across navigation
  Future<List<Map<String, dynamic>>> getDailyTrends(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final currentYear = startDate.year;

    // Check if we have cached data for this year
    if (_dailyDataCache != null && _cachedYear == currentYear) {
      AppLogger.i(
        '[TrendsService] Using cached daily trends: ${_dailyDataCache!.length} records',
      );
      // Filter cached data to requested range
      return _dailyDataCache!.where((item) {
        final dateStr = item['date'] as String?;
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr);
          return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              date.isBefore(endDate.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Try CSV data first
    final csvData = _getDailyTrendsFromCsv(startDate, endDate);
    if (csvData.isNotEmpty) {
      AppLogger.i(
        '[TrendsService] Using CSV data for daily trends: ${csvData.length} records',
      );
      // Cache the full year's data if requested range is the full year
      if (startDate.month == 1 &&
          startDate.day == 1 &&
          endDate.month == 12 &&
          endDate.day == 31) {
        _dailyDataCache = csvData;
        _cachedYear = currentYear;
      }
      return csvData;
    }

    // Fallback to Firestore
    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energy_trends')
              .doc('daily')
              .collection('data')
              .where('date', isGreaterThanOrEqualTo: _formatDate(startDate))
              .where('date', isLessThanOrEqualTo: _formatDate(endDate))
              .orderBy('date')
              .get();

      final firestoreData =
          query.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'date': data['date'],
              'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
              'totalCost': (data['totalCost'] ?? 0.0).toDouble(),
              'totalUsageTime': data['totalUsageTime'] ?? 0,
              'timestamp': data['timestamp'],
            };
          }).toList();

      // Cache the full year's data if requested range is the full year
      if (startDate.month == 1 &&
          startDate.day == 1 &&
          endDate.month == 12 &&
          endDate.day == 31) {
        _dailyDataCache = firestoreData;
        _cachedYear = currentYear;
      }

      return firestoreData;
    } catch (e) {
      AppLogger.i('[TrendsService] Error getting daily trends: $e');
      return [];
    }
  }

  /// Get weekly trends for a date range (CSV data first, then Firestore fallback)
  /// Uses persistent cache to maintain data across navigation
  Future<List<Map<String, dynamic>>> getWeeklyTrends(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final currentYear = startDate.year;

    // Check if we have cached data for this year
    if (_weeklyDataCache != null && _cachedYear == currentYear) {
      AppLogger.i(
        '[TrendsService] Using cached weekly trends: ${_weeklyDataCache!.length} records',
      );
      // Filter cached data to requested range
      return _weeklyDataCache!.where((item) {
        final startDateStr = item['startDate'] as String?;
        if (startDateStr == null) return false;
        try {
          final itemStart = DateTime.parse(startDateStr);
          return itemStart.isAfter(
                startDate.subtract(const Duration(days: 1)),
              ) &&
              itemStart.isBefore(endDate.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Try CSV data first
    final csvData = _getWeeklyTrendsFromCsv(startDate, endDate);
    if (csvData.isNotEmpty) {
      AppLogger.i(
        '[TrendsService] Using CSV data for weekly trends: ${csvData.length} records',
      );
      // Cache the full year's data if requested range covers the year
      final yearStart = DateTime(currentYear, 1, 1);
      final yearEnd = DateTime(currentYear, 12, 31);
      if (startDate.isBefore(yearStart.add(const Duration(days: 7))) &&
          endDate.isAfter(yearEnd.subtract(const Duration(days: 7)))) {
        _weeklyDataCache = csvData;
        _cachedYear = currentYear;
      }
      return csvData;
    }

    // Fallback to Firestore
    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energy_trends')
              .doc('weekly')
              .collection('data')
              .where(
                'startDate',
                isGreaterThanOrEqualTo: _formatDate(startDate),
              )
              .where('endDate', isLessThanOrEqualTo: _formatDate(endDate))
              .orderBy('startDate')
              .get();

      final firestoreData =
          query.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'week': data['week'],
              'startDate': data['startDate'],
              'endDate': data['endDate'],
              'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
              'totalCost': (data['totalCost'] ?? 0.0).toDouble(),
              'totalUsageTime': data['totalUsageTime'] ?? 0,
              'timestamp': data['timestamp'],
            };
          }).toList();

      // Cache the full year's data if requested range covers the year
      final yearStart = DateTime(currentYear, 1, 1);
      final yearEnd = DateTime(currentYear, 12, 31);
      if (startDate.isBefore(yearStart.add(const Duration(days: 7))) &&
          endDate.isAfter(yearEnd.subtract(const Duration(days: 7)))) {
        _weeklyDataCache = firestoreData;
        _cachedYear = currentYear;
      }

      return firestoreData;
    } catch (e) {
      AppLogger.i('[TrendsService] Error getting weekly trends: $e');
      return [];
    }
  }

  /// Get monthly trends for a date range (CSV data first, then Firestore fallback)
  /// Uses persistent cache to maintain data across navigation
  Future<List<Map<String, dynamic>>> getMonthlyTrends(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final currentYear = startDate.year;

    // Check if we have cached data for this year
    if (_monthlyDataCache != null && _cachedYear == currentYear) {
      AppLogger.i(
        '[TrendsService] Using cached monthly trends: ${_monthlyDataCache!.length} records',
      );
      // Filter cached data to requested range
      return _monthlyDataCache!.where((item) {
        final monthStr = item['month'] as String?;
        if (monthStr == null) return false;
        try {
          final parts = monthStr.split('-');
          if (parts.length == 2) {
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final monthStart = DateTime(year, month, 1);
            return monthStart.isAfter(
                  startDate.subtract(const Duration(days: 32)),
                ) &&
                monthStart.isBefore(endDate.add(const Duration(days: 32)));
          }
        } catch (_) {
          return false;
        }
        return false;
      }).toList();
    }

    // Try CSV data first
    final csvData = _getMonthlyTrendsFromCsv(startDate, endDate);
    if (csvData.isNotEmpty) {
      AppLogger.i(
        '[TrendsService] Using CSV data for monthly trends: ${csvData.length} records',
      );
      // Cache the full year's data if requested range covers the year
      final yearStart = DateTime(currentYear, 1, 1);
      final yearEnd = DateTime(currentYear, 12, 31);
      if (startDate.isBefore(yearStart.add(const Duration(days: 31))) &&
          endDate.isAfter(yearEnd.subtract(const Duration(days: 31)))) {
        _monthlyDataCache = csvData;
        _cachedYear = currentYear;
      }
      return csvData;
    }

    // Fallback to Firestore
    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energy_trends')
              .doc('monthly')
              .collection('data')
              .where(
                'startDate',
                isGreaterThanOrEqualTo: _formatDate(startDate),
              )
              .where('endDate', isLessThanOrEqualTo: _formatDate(endDate))
              .orderBy('startDate')
              .get();

      final firestoreData =
          query.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'month': data['month'],
              'startDate': data['startDate'],
              'endDate': data['endDate'],
              'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
              'totalCost': (data['totalCost'] ?? 0.0).toDouble(),
              'totalUsageTime': data['totalUsageTime'] ?? 0,
              'timestamp': data['timestamp'],
            };
          }).toList();

      // Cache the full year's data if requested range covers the year
      final yearStart = DateTime(currentYear, 1, 1);
      final yearEnd = DateTime(currentYear, 12, 31);
      if (startDate.isBefore(yearStart.add(const Duration(days: 31))) &&
          endDate.isAfter(yearEnd.subtract(const Duration(days: 31)))) {
        _monthlyDataCache = firestoreData;
        _cachedYear = currentYear;
      }

      return firestoreData;
    } catch (e) {
      AppLogger.i('[TrendsService] Error getting monthly trends: $e');
      return [];
    }
  }

  /// Stream of daily trends (last 30 days)
  Stream<List<Map<String, dynamic>>> listenToDailyTrends() {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('energy_trends')
        .doc('daily')
        .collection('data')
        .where('date', isGreaterThanOrEqualTo: _formatDate(startDate))
        .where('date', isLessThanOrEqualTo: _formatDate(endDate))
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'date': data['date'],
              'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
              'totalCost': (data['totalCost'] ?? 0.0).toDouble(),
              'totalUsageTime': data['totalUsageTime'] ?? 0,
              'timestamp': data['timestamp'],
            };
          }).toList();
        });
  }

  /// Stream of weekly trends
  Stream<List<Map<String, dynamic>>> listenToWeeklyTrends() {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 90));

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('energy_trends')
        .doc('weekly')
        .collection('data')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'week': data['week'],
              'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
              'totalCost': (data['totalCost'] ?? 0.0).toDouble(),
              'totalUsageTime': data['totalUsageTime'] ?? 0,
              'timestamp': data['timestamp'],
            };
          }).toList();
        });
  }

  /// Stream of monthly trends
  Stream<List<Map<String, dynamic>>> listenToMonthlyTrends() {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 365));

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('energy_trends')
        .doc('monthly')
        .collection('data')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'month': data['month'],
              'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
              'totalCost': (data['totalCost'] ?? 0.0).toDouble(),
              'totalUsageTime': data['totalUsageTime'] ?? 0,
              'timestamp': data['timestamp'],
            };
          }).toList();
        });
  }

  /// Get today's usage from Realtime DB
  Future<Map<String, dynamic>> _getTodayUsageFromRealtimeDB() async {
    final snapshot = await _database.ref('users/$_userId/todayUsage').get();

    if (!snapshot.exists) {
      return {'totalKwh': 0.0, 'totalUsageTime': 0};
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return {
      'totalKwh': (data['totalKwh'] ?? 0.0).toDouble(),
      'totalUsageTime': data['totalUsageTime'] ?? 0,
    };
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
      AppLogger.i('[TrendsService] Error getting power rate: $e');
    }

    return 12.50; // Default rate
  }

  /// Helper methods
  String _getWeekKey(DateTime date) {
    final startOfWeek = _getStartOfWeek(date);
    final year = startOfWeek.year;
    final week =
        ((startOfWeek.difference(DateTime(year, 1, 1)).inDays) / 7).floor() + 1;
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  DateTime _getEndOfWeek(DateTime date) {
    final startOfWeek = _getStartOfWeek(date);
    return startOfWeek.add(const Duration(days: 6));
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse month string (e.g., "2025-08") to DateTime
  DateTime? _parseMonthString(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return DateTime(year, month, 1);
      }
    } catch (e) {
      AppLogger.w('[TrendsService] Error parsing month string: $monthStr');
    }
    return null;
  }

  /// Get CSV dataset
  List<PredictiveDataModel> _getCsvDataset() {
    try {
      // Ensure dataset is initialized
      if (!_predictiveDatasetService.hasDataset) {
        _predictiveDatasetService.initialize();
      }
      return _predictiveDatasetService.dataset;
    } catch (e) {
      AppLogger.w('[TrendsService] Error getting CSV dataset: $e');
      return [];
    }
  }

  /// Get monthly trends from CSV data
  List<Map<String, dynamic>> _getMonthlyTrendsFromCsv(
    DateTime startDate,
    DateTime endDate,
  ) {
    final csvData = _getCsvDataset();
    if (csvData.isEmpty) return [];

    final monthlyData = <String, Map<String, dynamic>>{};

    // Group CSV data by month
    for (final record in csvData) {
      final monthDate = _parseMonthString(record.month);
      if (monthDate == null) continue;

      // Check if month overlaps with date range
      final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0);
      if (monthEnd.isBefore(startDate) || monthDate.isAfter(endDate)) continue;

      final monthKey =
          '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';

      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {
          'month': monthKey,
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'startDate': _formatDate(monthDate),
          'endDate': _formatDate(monthEnd),
        };
      }

      monthlyData[monthKey]!['totalKwh'] =
          (monthlyData[monthKey]!['totalKwh'] as double) + record.energyKwh;
      monthlyData[monthKey]!['totalCost'] =
          (monthlyData[monthKey]!['totalCost'] as double) + record.cost;
    }

    // Convert to list and sort by month
    final result = monthlyData.values.toList();
    result.sort(
      (a, b) => (a['month'] as String).compareTo(b['month'] as String),
    );

    return result;
  }

  /// Get weekly trends from CSV data (aggregate monthly data by weeks)
  List<Map<String, dynamic>> _getWeeklyTrendsFromCsv(
    DateTime startDate,
    DateTime endDate,
  ) {
    final csvData = _getCsvDataset();
    if (csvData.isEmpty) return [];

    final weeklyData = <String, Map<String, dynamic>>{};

    // Process each month's data and distribute to weeks
    for (final record in csvData) {
      final monthDate = _parseMonthString(record.month);
      if (monthDate == null) continue;

      if (monthDate.isBefore(startDate) || monthDate.isAfter(endDate)) continue;

      // Get days in month
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

      // Calculate daily average kWh and cost
      final dailyKwh = record.energyKwh / daysInMonth;
      final dailyCost = record.cost / daysInMonth;

      // Distribute across weeks in the month
      final monthStart = DateTime(monthDate.year, monthDate.month, 1);
      final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0);

      DateTime currentDate = monthStart;
      while (currentDate.isBefore(monthEnd) ||
          currentDate.isAtSameMomentAs(monthEnd)) {
        if (currentDate.isBefore(startDate) || currentDate.isAfter(endDate)) {
          currentDate = currentDate.add(const Duration(days: 1));
          continue;
        }

        final weekStart = _getStartOfWeek(currentDate);
        final weekKey = _getWeekKey(currentDate);

        if (!weeklyData.containsKey(weekKey)) {
          weeklyData[weekKey] = {
            'week': weekKey,
            'totalKwh': 0.0,
            'totalCost': 0.0,
            'startDate': _formatDate(weekStart),
            'endDate': _formatDate(_getEndOfWeek(currentDate)),
          };
        }

        weeklyData[weekKey]!['totalKwh'] =
            (weeklyData[weekKey]!['totalKwh'] as double) + dailyKwh;
        weeklyData[weekKey]!['totalCost'] =
            (weeklyData[weekKey]!['totalCost'] as double) + dailyCost;

        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    final result = weeklyData.values.toList();
    result.sort(
      (a, b) => (a['startDate'] as String).compareTo(b['startDate'] as String),
    );

    return result;
  }

  /// Get daily trends from CSV data (distribute monthly data across days with realistic variation)
  List<Map<String, dynamic>> _getDailyTrendsFromCsv(
    DateTime startDate,
    DateTime endDate,
  ) {
    final csvData = _getCsvDataset();
    if (csvData.isEmpty) return [];

    final dailyData = <String, Map<String, dynamic>>{};

    // Process each month's data and distribute to days with realistic variation
    for (final record in csvData) {
      final monthDate = _parseMonthString(record.month);
      if (monthDate == null) continue;

      if (monthDate.isBefore(startDate) || monthDate.isAfter(endDate)) continue;

      // Get days in month
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

      // Calculate base daily average kWh and cost
      final baseDailyKwh = record.energyKwh / daysInMonth;
      final baseDailyCost = record.cost / daysInMonth;

      // Distribute across days in the month with realistic variation
      final monthStart = DateTime(monthDate.year, monthDate.month, 1);
      final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0);

      // Calculate variation factors for each day in the month
      // Use a map to store factors by date key for proper alignment
      final Map<String, double> variationFactors = {};
      double totalVariation = 0.0;

      DateTime currentDate = monthStart;
      while (currentDate.isBefore(monthEnd) ||
          currentDate.isAtSameMomentAs(monthEnd)) {
        // Only process dates within the requested range
        if (currentDate.isBefore(startDate) || currentDate.isAfter(endDate)) {
          currentDate = currentDate.add(const Duration(days: 1));
          continue;
        }

        final dateKey = _formatDate(currentDate);

        // Create seeded random based on date for consistency
        // Same date will always produce same variation
        final dateSeed =
            currentDate.year * 10000 +
            currentDate.month * 100 +
            currentDate.day;
        final random = math.Random(dateSeed);

        // Day of week (1 = Monday, 7 = Sunday)
        final weekday = currentDate.weekday;
        final isWeekend = weekday == 6 || weekday == 7; // Saturday or Sunday

        // Base variation factors
        double variationFactor = 1.0;

        // Weekend pattern: weekends typically 20-30% higher usage
        if (isWeekend) {
          variationFactor *=
              (1.0 + random.nextDouble() * 0.3 + 0.2); // 1.2 to 1.5x
        } else {
          // Weekdays: slight variation
          variationFactor *= (0.9 + random.nextDouble() * 0.2); // 0.9 to 1.1x
        }

        // Day-of-week specific patterns
        switch (weekday) {
          case 1: // Monday - often higher after weekend
            variationFactor *=
                (1.05 + random.nextDouble() * 0.15); // 1.05 to 1.2x
            break;
          case 5: // Friday - slightly higher
            variationFactor *= (1.0 + random.nextDouble() * 0.1); // 1.0 to 1.1x
            break;
          case 6: // Saturday - highest weekend day
            variationFactor *=
                (1.15 + random.nextDouble() * 0.25); // 1.15 to 1.4x
            break;
          case 7: // Sunday - moderate weekend day
            variationFactor *= (1.1 + random.nextDouble() * 0.2); // 1.1 to 1.3x
            break;
          default: // Tuesday-Thursday - normal
            variationFactor *=
                (0.85 + random.nextDouble() * 0.25); // 0.85 to 1.1x
            break;
        }

        // Add random daily fluctuation (±25% from current factor)
        final dailyFluctuation =
            0.75 + (random.nextDouble() * 0.5); // 0.75 to 1.25
        variationFactor *= dailyFluctuation;

        // Occasional peak days (10% chance of being 1.5-2x higher)
        if (random.nextDouble() < 0.1) {
          variationFactor *= (1.5 + random.nextDouble() * 0.5); // 1.5 to 2.0x
        }

        // Occasional low days (10% chance of being 0.5-0.7x lower)
        if (random.nextDouble() < 0.1) {
          variationFactor *= (0.5 + random.nextDouble() * 0.2); // 0.5 to 0.7x
        }

        variationFactors[dateKey] = variationFactor;
        totalVariation += variationFactor;
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Normalize factors to ensure monthly total is maintained
      if (totalVariation > 0 && variationFactors.isNotEmpty) {
        final normalizationFactor = variationFactors.length / totalVariation;
        for (final key in variationFactors.keys) {
          variationFactors[key] = variationFactors[key]! * normalizationFactor;
        }
      }

      // Apply variation factors to distribute data
      for (final entry in variationFactors.entries) {
        final dateKey = entry.key;
        final variationFactor = entry.value;

        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = {
            'date': dateKey,
            'totalKwh': 0.0,
            'totalCost': 0.0,
            'totalUsageTime': 0,
          };
        }

        // Apply variation factor
        dailyData[dateKey]!['totalKwh'] =
            (dailyData[dateKey]!['totalKwh'] as double) +
            (baseDailyKwh * variationFactor);
        dailyData[dateKey]!['totalCost'] =
            (dailyData[dateKey]!['totalCost'] as double) +
            (baseDailyCost * variationFactor);
      }
    }

    final result = dailyData.values.toList();
    result.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    return result;
  }

  /// Get chart data for specific period
  Future<List<Map<String, dynamic>>> getChartData(
    String period,
    int days,
  ) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    switch (period.toLowerCase()) {
      case 'daily':
        return await getDailyTrends(startDate, endDate);
      case 'weekly':
        return await getWeeklyTrends(startDate, endDate);
      case 'monthly':
        return await getMonthlyTrends(startDate, endDate);
      default:
        return await getDailyTrends(startDate, endDate);
    }
  }

  /// Generate dummy monthly and weekly trend data for testing (3 months)
  /// This is useful when Firestore is empty and you need sample data
  Future<bool> generateDummyTrendData() async {
    if (_userId.isEmpty) {
      AppLogger.w(
        '[TrendsService] Cannot generate dummy data: user not authenticated',
      );
      return false;
    }

    try {
      AppLogger.i(
        '[TrendsService] Generating dummy monthly and weekly trend data...',
      );

      final now = DateTime.now();
      final powerRate = await _getCurrentPowerRate();

      // Generate data for the last 3 months (including current month)
      final monthlyData = <String, Map<String, dynamic>>{};
      final weeklyData = <String, Map<String, dynamic>>{};

      // Generate 3 months of data
      for (int monthOffset = 2; monthOffset >= 0; monthOffset--) {
        final targetDate = DateTime(now.year, now.month - monthOffset, 1);
        final monthKey =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}';

        // Generate realistic monthly kWh (50-150 kWh range)
        final baseKwh = 75.0 + (monthOffset * 10.0); // Varying values
        final monthlyKwh =
            baseKwh + (DateTime.now().millisecondsSinceEpoch % 50);
        final monthlyCost = monthlyKwh * powerRate;
        final daysInMonth =
            DateTime(targetDate.year, targetDate.month + 1, 0).day;
        final monthlyUsageTime =
            (daysInMonth * 12 * 3600).toInt(); // ~12 hours per day average

        final startOfMonth = DateTime(targetDate.year, targetDate.month, 1);
        final endOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0);

        // Store monthly data
        monthlyData[monthKey] = {
          'totalKwh': monthlyKwh,
          'totalCost': monthlyCost,
          'totalUsageTime': monthlyUsageTime,
          'month': monthKey,
          'startDate': _formatDate(startOfMonth),
          'endDate': _formatDate(endOfMonth),
          'timestamp': Timestamp.fromDate(endOfMonth),
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Generate weekly data for this month
        DateTime currentWeekStart = startOfMonth;

        while (currentWeekStart.isBefore(endOfMonth) ||
            currentWeekStart.isAtSameMomentAs(endOfMonth)) {
          final weekStart = _getStartOfWeek(currentWeekStart);
          final weekEnd = _getEndOfWeek(currentWeekStart);

          // Adjust week start/end to be within the month
          final adjustedWeekStart =
              weekStart.isBefore(startOfMonth) ? startOfMonth : weekStart;
          final adjustedWeekEnd =
              weekEnd.isAfter(endOfMonth) ? endOfMonth : weekEnd;

          // Calculate days in this week
          final daysInWeek =
              adjustedWeekEnd.difference(adjustedWeekStart).inDays + 1;
          final daysInMonthTotal =
              endOfMonth.difference(startOfMonth).inDays + 1;

          // Calculate weekly kWh and cost proportionally
          final weeklyKwh = (monthlyKwh * daysInWeek) / daysInMonthTotal;
          final weeklyCost = weeklyKwh * powerRate;
          final weeklyUsageTime = (daysInWeek * 12 * 3600).toInt();

          final weekKey = _getWeekKey(currentWeekStart);

          // Store weekly data (only if not already stored)
          if (!weeklyData.containsKey(weekKey)) {
            weeklyData[weekKey] = {
              'totalKwh': weeklyKwh,
              'totalCost': weeklyCost,
              'totalUsageTime': weeklyUsageTime,
              'week': weekKey,
              'startDate': _formatDate(adjustedWeekStart),
              'endDate': _formatDate(adjustedWeekEnd),
              'timestamp': Timestamp.fromDate(adjustedWeekEnd),
              'createdAt': FieldValue.serverTimestamp(),
            };
          }

          // Move to next week
          currentWeekStart = weekEnd.add(const Duration(days: 1));
        }
      }

      // Save monthly data to Firestore
      for (final entry in monthlyData.entries) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('energy_trends')
            .doc('monthly')
            .collection('data')
            .doc(entry.key)
            .set(entry.value, SetOptions(merge: true));

        AppLogger.i(
          '[TrendsService] Generated monthly data for ${entry.key}: ${entry.value['totalKwh'].toStringAsFixed(2)} kWh, ₱${entry.value['totalCost'].toStringAsFixed(2)}',
        );
      }

      // Save weekly data to Firestore
      for (final entry in weeklyData.entries) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('energy_trends')
            .doc('weekly')
            .collection('data')
            .doc(entry.key)
            .set(entry.value, SetOptions(merge: true));

        AppLogger.i(
          '[TrendsService] Generated weekly data for ${entry.key}: ${entry.value['totalKwh'].toStringAsFixed(2)} kWh, ₱${entry.value['totalCost'].toStringAsFixed(2)}',
        );
      }

      AppLogger.i(
        '[TrendsService] Successfully generated ${monthlyData.length} monthly and ${weeklyData.length} weekly trend records',
      );

      // Update monitoring dataset reference with new data
      final monitoringDatasetService = MonitoringDatasetService();
      await monitoringDatasetService.updateDatasetReference();

      return true;
    } catch (e) {
      AppLogger.e('[TrendsService] Error generating dummy trend data: $e');
      return false;
    }
  }

  /// Get energy efficiency metrics
  Future<Map<String, dynamic>> getEfficiencyMetrics() async {
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));

    final dailyTrends = await getDailyTrends(last30Days, now);

    if (dailyTrends.isEmpty) {
      return {
        'averageDailyKwh': 0.0,
        'averageDailyCost': 0.0,
        'peakUsageDay': null,
        'lowestUsageDay': null,
        'trend': 'stable',
        'efficiencyScore': 0.0,
      };
    }

    final totalKwh = dailyTrends.fold(0.0, (sum, day) => sum + day['totalKwh']);
    final totalCost = dailyTrends.fold(
      0.0,
      (sum, day) => sum + day['totalCost'],
    );
    final averageDailyKwh = totalKwh / dailyTrends.length;
    final averageDailyCost = totalCost / dailyTrends.length;

    // Find peak and lowest usage days
    dailyTrends.sort(
      (a, b) => (b['totalKwh'] as double).compareTo(a['totalKwh'] as double),
    );
    final peakUsageDay = dailyTrends.first;
    final lowestUsageDay = dailyTrends.last;

    // Calculate trend (simplified)
    String trend = 'stable';
    if (dailyTrends.length >= 7) {
      final firstWeek =
          dailyTrends.take(7).fold(0.0, (sum, day) => sum + day['totalKwh']) /
          7;
      final lastWeek =
          dailyTrends
              .skip(dailyTrends.length - 7)
              .fold(0.0, (sum, day) => sum + day['totalKwh']) /
          7;

      if (lastWeek > firstWeek * 1.1) {
        trend = 'increasing';
      } else if (lastWeek < firstWeek * 0.9) {
        trend = 'decreasing';
      }
    }

    // Calculate efficiency score (0-100)
    final efficiencyScore =
        (100 - (averageDailyKwh / 10).clamp(0, 100)).toDouble();

    return {
      'averageDailyKwh': averageDailyKwh,
      'averageDailyCost': averageDailyCost,
      'peakUsageDay': peakUsageDay,
      'lowestUsageDay': lowestUsageDay,
      'trend': trend,
      'efficiencyScore': efficiencyScore,
      'totalDays': dailyTrends.length,
    };
  }
}
