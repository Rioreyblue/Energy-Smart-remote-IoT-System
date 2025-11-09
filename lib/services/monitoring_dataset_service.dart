import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/monitoring_dataset_model.dart';
import '../utils/app_logger.dart';
import '../services/trends_service.dart';

/// Service for managing 3-month dataset reference in Firestore
class MonitoringDatasetService {
  static final MonitoringDatasetService _instance =
      MonitoringDatasetService._internal();
  factory MonitoringDatasetService() => _instance;
  MonitoringDatasetService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  StreamSubscription<QuerySnapshot>? _monthlyTrendsSubscription;

  String? get _userId => _auth.currentUser?.uid;

  DocumentReference get _datasetRef {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(_userId!)
        .collection('monitoring_dataset')
        .doc('reference');
  }

  /// Standardized appliance labels
  static const List<String> applianceLabels = [
    'appliances_001',
    'appliances_002',
    'appliances_003',
    'appliances_004',
  ];

  /// Get current dataset reference
  Future<MonitoringDatasetModel?> getDatasetReference() async {
    if (_userId == null) {
      AppLogger.w('[MonitoringDatasetService] User not authenticated');
      return null;
    }

    try {
      final doc = await _datasetRef.get();
      if (!doc.exists) {
        AppLogger.i(
          '[MonitoringDatasetService] Dataset reference not found, will create on next update',
        );
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      final dataset = MonitoringDatasetModel.fromFirestore(data);

      AppLogger.i(
        '[MonitoringDatasetService] Loaded dataset reference: ${dataset.monthlyData.length} months',
      );
      return dataset;
    } catch (e) {
      AppLogger.e(
        '[MonitoringDatasetService] Error loading dataset reference: $e',
      );
      return null;
    }
  }

  /// Update dataset reference with latest 3 months of data
  Future<bool> updateDatasetReference() async {
    if (_userId == null) {
      AppLogger.w('[MonitoringDatasetService] User not authenticated');
      return false;
    }

    try {
      AppLogger.i('[MonitoringDatasetService] Updating dataset reference...');

      // Get latest 3 months of monthly trends
      final monthlyTrends = await _getLatestMonthlyTrends(3);

      if (monthlyTrends.isEmpty) {
        AppLogger.w(
          '[MonitoringDatasetService] No monthly trends available for dataset',
        );
        return false;
      }

      // Build monthly data with appliance breakdown
      final List<MonthlyDatasetEntry> monthlyData = [];
      for (final trend in monthlyTrends) {
        final monthKey = trend['month'] as String;
        final totalKwh = (trend['totalKwh'] ?? 0.0).toDouble();
        final totalCost = (trend['totalCost'] ?? 0.0).toDouble();
        final timestamp =
            trend['timestamp'] is Timestamp
                ? (trend['timestamp'] as Timestamp).toDate()
                : DateTime.parse(
                  trend['timestamp'] ?? DateTime.now().toIso8601String(),
                );

        // Get appliance breakdown for this month
        final applianceBreakdown = await _getApplianceBreakdownForMonth(
          monthKey,
          totalKwh,
          totalCost,
        );

        monthlyData.add(
          MonthlyDatasetEntry(
            month: monthKey,
            totalKwh: totalKwh,
            totalCost: totalCost,
            appliances: applianceBreakdown,
            timestamp: timestamp,
          ),
        );
      }

      // Create dataset model
      final dataset = MonitoringDatasetModel(
        monthlyData: monthlyData,
        lastUpdated: DateTime.now(),
        applianceLabels: applianceLabels,
      );

      // Save to Firestore
      await _datasetRef.set(dataset.toFirestore(), SetOptions(merge: true));

      AppLogger.i(
        '[MonitoringDatasetService] Dataset reference updated successfully: ${monthlyData.length} months',
      );
      return true;
    } catch (e) {
      AppLogger.e(
        '[MonitoringDatasetService] Error updating dataset reference: $e',
      );
      return false;
    }
  }

  /// Get latest N months of monthly trends
  Future<List<Map<String, dynamic>>> _getLatestMonthlyTrends(int count) async {
    if (_userId == null) return [];

    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_userId!)
              .collection('energy_trends')
              .doc('monthly')
              .collection('data')
              .orderBy('timestamp', descending: true)
              .limit(count)
              .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'month': data['month'] ?? doc.id,
          'totalKwh': data['totalKwh'] ?? 0.0,
          'totalCost': data['totalCost'] ?? 0.0,
          'totalUsageTime': data['totalUsageTime'] ?? 0,
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      AppLogger.e(
        '[MonitoringDatasetService] Error getting monthly trends: $e',
      );
      return [];
    }
  }

  /// Get appliance breakdown for a specific month
  Future<Map<String, ApplianceData>> _getApplianceBreakdownForMonth(
    String monthKey,
    double totalKwh,
    double totalCost,
  ) async {
    final Map<String, ApplianceData> breakdown = {};

    try {
      // Try to get appliance breakdown from Realtime DB
      // Get appliances snapshot at the end of the month
      final appliancesSnapshot =
          await _database.ref('users/$_userId/appliances').get();

      if (appliancesSnapshot.exists && appliancesSnapshot.value != null) {
        final appliancesMap = Map<String, dynamic>.from(
          appliancesSnapshot.value as Map,
        );
        final powerRate = await _getCurrentPowerRate();

        // Calculate total kwh from all appliances
        double totalApplianceKwh = 0.0;
        final applianceKwhMap = <String, double>{};

        for (final entry in appliancesMap.entries) {
          final applianceId = entry.key;
          final applianceData = Map<String, dynamic>.from(entry.value as Map);
          final applianceKwh = (applianceData['kwh'] ?? 0.0).toDouble();

          // Only include standardized appliance labels
          if (applianceLabels.contains(applianceId)) {
            applianceKwhMap[applianceId] = applianceKwh;
            totalApplianceKwh += applianceKwh;
          }
        }

        // If we have appliance data, distribute proportionally
        if (totalApplianceKwh > 0 && applianceKwhMap.isNotEmpty) {
          // Scale appliance kwh to match total monthly kwh
          final scaleFactor = totalKwh / totalApplianceKwh;

          for (final applianceLabel in applianceLabels) {
            final applianceKwh = applianceKwhMap[applianceLabel] ?? 0.0;
            final scaledKwh = applianceKwh * scaleFactor;
            final applianceCost = scaledKwh * powerRate;

            breakdown[applianceLabel] = ApplianceData(
              kwh: scaledKwh,
              cost: applianceCost,
            );
          }
        } else {
          // Fallback: distribute evenly among appliances
          final kwhPerAppliance = totalKwh / applianceLabels.length;
          final costPerAppliance = totalCost / applianceLabels.length;

          for (final applianceLabel in applianceLabels) {
            breakdown[applianceLabel] = ApplianceData(
              kwh: kwhPerAppliance,
              cost: costPerAppliance,
            );
          }
        }
      } else {
        // No appliance data, distribute evenly
        final kwhPerAppliance = totalKwh / applianceLabels.length;
        final costPerAppliance = totalCost / applianceLabels.length;

        for (final applianceLabel in applianceLabels) {
          breakdown[applianceLabel] = ApplianceData(
            kwh: kwhPerAppliance,
            cost: costPerAppliance,
          );
        }
      }
    } catch (e) {
      AppLogger.w(
        '[MonitoringDatasetService] Error getting appliance breakdown: $e, using even distribution',
      );

      // Fallback: distribute evenly
      final kwhPerAppliance = totalKwh / applianceLabels.length;
      final costPerAppliance = totalCost / applianceLabels.length;

      for (final applianceLabel in applianceLabels) {
        breakdown[applianceLabel] = ApplianceData(
          kwh: kwhPerAppliance,
          cost: costPerAppliance,
        );
      }
    }

    return breakdown;
  }

  /// Get current power rate from Firestore
  Future<double> _getCurrentPowerRate() async {
    try {
      final doc =
          await _firestore
              .collection('admin_settings')
              .doc('system_config')
              .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['powerRate'] != null) {
          return (data['powerRate'] as num).toDouble();
        }
      }
    } catch (e) {
      AppLogger.w('[MonitoringDatasetService] Error getting power rate: $e');
    }

    return 12.50; // Default rate
  }

  /// Listen to monthly trends and auto-update dataset reference
  void startAutoUpdate() {
    if (_userId == null) return;

    _monthlyTrendsSubscription?.cancel();

    _monthlyTrendsSubscription = _firestore
        .collection('users')
        .doc(_userId!)
        .collection('energy_trends')
        .doc('monthly')
        .collection('data')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isNotEmpty) {
              // New monthly data available, update dataset reference
              updateDatasetReference().catchError((e) {
                AppLogger.e(
                  '[MonitoringDatasetService] Error in auto-update: $e',
                );
                return false;
              });
            }
          },
          onError: (error) {
            AppLogger.e(
              '[MonitoringDatasetService] Error listening to monthly trends: $error',
            );
          },
        );

    AppLogger.i('[MonitoringDatasetService] Auto-update listener started');
  }

  /// Stop auto-update listener
  void stopAutoUpdate() {
    _monthlyTrendsSubscription?.cancel();
    _monthlyTrendsSubscription = null;
    AppLogger.i('[MonitoringDatasetService] Auto-update listener stopped');
  }

  /// Initialize and update dataset reference
  Future<void> initialize() async {
    if (_userId == null) {
      AppLogger.w(
        '[MonitoringDatasetService] User not authenticated, skipping initialization',
      );
      return;
    }

    try {
      // Check if monthly trends exist in Firestore
      final hasMonthlyTrends = await _checkMonthlyTrendsExist();

      // If no monthly trends exist, auto-generate dummy data
      if (!hasMonthlyTrends) {
        AppLogger.i(
          '[MonitoringDatasetService] No monthly trends found, auto-generating dummy data...',
        );
        final trendsService = TrendsService();
        final generated = await trendsService.generateDummyTrendData();
        if (generated) {
          AppLogger.i(
            '[MonitoringDatasetService] Successfully generated dummy monthly and weekly trend data',
          );
        } else {
          AppLogger.w(
            '[MonitoringDatasetService] Failed to generate dummy data, will use embedded dataset',
          );
        }
      }

      // Check if dataset reference exists
      final existingDataset = await getDatasetReference();
      if (existingDataset == null) {
        // Try to update/create it
        AppLogger.i(
          '[MonitoringDatasetService] Dataset reference not found, creating...',
        );
        final updated = await updateDatasetReference();
        if (!updated) {
          AppLogger.w(
            '[MonitoringDatasetService] Failed to create dataset reference, will retry when monthly trends are available',
          );
          // Create empty dataset reference structure so it exists
          await _createEmptyDatasetReference();
        }
      } else {
        AppLogger.i(
          '[MonitoringDatasetService] Dataset reference exists with ${existingDataset.monthlyData.length} months',
        );
        // If dataset exists but is empty, try to populate it
        if (existingDataset.monthlyData.isEmpty) {
          AppLogger.i(
            '[MonitoringDatasetService] Dataset reference is empty, attempting to populate...',
          );
          await updateDatasetReference();
        }
      }
    } catch (e) {
      AppLogger.e('[MonitoringDatasetService] Error during initialization: $e');
    }

    // Start auto-update listener
    startAutoUpdate();
  }

  /// Check if monthly trends exist in Firestore
  Future<bool> _checkMonthlyTrendsExist() async {
    if (_userId == null) return false;

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(_userId!)
              .collection('energy_trends')
              .doc('monthly')
              .collection('data')
              .limit(1)
              .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      AppLogger.w(
        '[MonitoringDatasetService] Error checking monthly trends: $e',
      );
      return false;
    }
  }

  /// Create empty dataset reference structure
  Future<void> _createEmptyDatasetReference() async {
    if (_userId == null) return;

    try {
      await _datasetRef.set({
        'monthlyData': [],
        'lastUpdated': FieldValue.serverTimestamp(),
        'applianceLabels': applianceLabels,
      });
      AppLogger.i(
        '[MonitoringDatasetService] Created empty dataset reference structure',
      );
    } catch (e) {
      AppLogger.e(
        '[MonitoringDatasetService] Error creating empty dataset reference: $e',
      );
    }
  }

  /// Get monthly data in chart-compatible format (for MonitoringChartCard)
  /// Returns list of maps with totalKwh, totalCost, and month for the latest 3 months
  Future<List<Map<String, dynamic>>> getMonthlyDataForCharts() async {
    final dataset = await getDatasetReference();
    if (dataset == null || dataset.monthlyData.isEmpty) {
      return [];
    }

    // Return in format compatible with MonitoringChartCard
    return dataset.monthlyData.map((entry) {
      return {
        'month': entry.month,
        'totalKwh': entry.totalKwh,
        'totalCost': entry.totalCost,
        'timestamp': Timestamp.fromDate(entry.timestamp),
      };
    }).toList();
  }

  /// Get monthly data with appliance breakdown (for advanced charts)
  Future<List<MonthlyDatasetEntry>> getMonthlyDataWithBreakdown() async {
    final dataset = await getDatasetReference();
    if (dataset == null) {
      return [];
    }
    return dataset.monthlyData;
  }

  /// Dispose resources
  void dispose() {
    stopAutoUpdate();
  }
}
