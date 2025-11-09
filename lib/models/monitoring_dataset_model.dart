import 'package:cloud_firestore/cloud_firestore.dart';
import 'predictive_data_model.dart';

/// Model for monthly dataset entry with appliance breakdown
class MonthlyDatasetEntry {
  final String month;
  final double totalKwh;
  final double totalCost;
  final Map<String, ApplianceData> appliances;
  final DateTime timestamp;

  MonthlyDatasetEntry({
    required this.month,
    required this.totalKwh,
    required this.totalCost,
    required this.appliances,
    required this.timestamp,
  });

  factory MonthlyDatasetEntry.fromMap(Map<String, dynamic> map) {
    final appliancesMap = map['appliances'] as Map<String, dynamic>? ?? {};
    final appliances = appliancesMap.map(
      (key, value) => MapEntry(
        key,
        ApplianceData.fromMap(Map<String, dynamic>.from(value)),
      ),
    );

    return MonthlyDatasetEntry(
      month: map['month'] ?? '',
      totalKwh: (map['totalKwh'] ?? 0.0).toDouble(),
      totalCost: (map['totalCost'] ?? 0.0).toDouble(),
      appliances: appliances,
      timestamp:
          map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.parse(
                map['timestamp'] ?? DateTime.now().toIso8601String(),
              ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'totalKwh': totalKwh,
      'totalCost': totalCost,
      'appliances': appliances.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

/// Model for appliance data in monthly entry
class ApplianceData {
  final double kwh;
  final double cost;

  ApplianceData({required this.kwh, required this.cost});

  factory ApplianceData.fromMap(Map<String, dynamic> map) {
    return ApplianceData(
      kwh: (map['kwh'] ?? 0.0).toDouble(),
      cost: (map['cost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'kwh': kwh, 'cost': cost};
  }
}

/// Model for monitoring dataset reference
class MonitoringDatasetModel {
  final List<MonthlyDatasetEntry> monthlyData;
  final DateTime lastUpdated;
  final List<String> applianceLabels;

  MonitoringDatasetModel({
    required this.monthlyData,
    required this.lastUpdated,
    required this.applianceLabels,
  });

  factory MonitoringDatasetModel.fromFirestore(Map<String, dynamic> data) {
    final monthlyDataList =
        (data['monthlyData'] as List<dynamic>? ?? [])
            .map(
              (item) =>
                  MonthlyDatasetEntry.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList();

    final lastUpdated =
        data['lastUpdated'] is Timestamp
            ? (data['lastUpdated'] as Timestamp).toDate()
            : DateTime.parse(
              data['lastUpdated'] ?? DateTime.now().toIso8601String(),
            );

    final applianceLabels =
        (data['applianceLabels'] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .toList();

    return MonitoringDatasetModel(
      monthlyData: monthlyDataList,
      lastUpdated: lastUpdated,
      applianceLabels: applianceLabels,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monthlyData': monthlyData.map((entry) => entry.toMap()).toList(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'applianceLabels': applianceLabels,
    };
  }

  /// Convert to PredictiveDataModel format for AI predictions
  List<PredictiveDataModel> toPredictiveDataModels() {
    final List<PredictiveDataModel> predictiveData = [];

    for (final monthlyEntry in monthlyData) {
      for (final applianceLabel in applianceLabels) {
        final applianceData =
            monthlyEntry.appliances[applianceLabel] ??
            ApplianceData(kwh: 0.0, cost: 0.0);

        // Calculate hours per day (approximate: monthly kWh / (power * days))
        // For estimation, assume average power of 100W if not available
        final estimatedPower = 100.0; // watts
        final daysInMonth = _getDaysInMonth(monthlyEntry.month);
        final hoursPerDay =
            applianceData.kwh > 0 && daysInMonth > 0
                ? (applianceData.kwh * 1000) / (estimatedPower * daysInMonth)
                : 0.0;

        // Calculate rate from cost and kwh
        final rate =
            applianceData.kwh > 0
                ? applianceData.cost / applianceData.kwh
                : 12.50;

        // Calculate voltage and current (estimates based on power)
        final voltage = 220.0; // Standard voltage in Philippines
        final current = estimatedPower / voltage;

        predictiveData.add(
          PredictiveDataModel(
            id: '${monthlyEntry.month}_$applianceLabel',
            month: monthlyEntry.month,
            appliance: applianceLabel,
            voltage: voltage,
            current: current,
            power: estimatedPower,
            hoursPerDay: hoursPerDay,
            energyKwh: applianceData.kwh,
            rate: rate,
            cost: applianceData.cost,
            createdAt: monthlyEntry.timestamp,
          ),
        );
      }
    }

    return predictiveData;
  }

  /// Get number of days in a month (format: YYYY-MM)
  int _getDaysInMonth(String monthKey) {
    try {
      final parts = monthKey.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return DateTime(year, month + 1, 0).day;
      }
    } catch (e) {
      // Fallback to 30 days
    }
    return 30;
  }

  /// Get total number of records
  int get totalRecords => monthlyData.length * applianceLabels.length;

  /// Check if dataset is valid (has 3 months of data)
  bool get isValid => monthlyData.length >= 3;
}
