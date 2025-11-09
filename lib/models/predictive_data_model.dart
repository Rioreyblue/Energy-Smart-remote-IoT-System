import 'dart:convert';

/// Model for predictive consumption dataset entries
class PredictiveDataModel {
  final String id;
  final String month;
  final String appliance;
  final double voltage;
  final double current;
  final double power;
  final double hoursPerDay;
  final double energyKwh;
  final double rate;
  final double cost;
  final DateTime? createdAt;

  const PredictiveDataModel({
    required this.id,
    required this.month,
    required this.appliance,
    required this.voltage,
    required this.current,
    required this.power,
    required this.hoursPerDay,
    required this.energyKwh,
    required this.rate,
    required this.cost,
    this.createdAt,
  });

  /// Create from CSV row (List of dynamic values)
  factory PredictiveDataModel.fromCsv(
    List<dynamic> row,
    Map<String, int> columnMap,
  ) {
    try {
      // Calculate hoursPerDay if not provided (from power and energy)
      double hoursPerDay =
          _getDoubleValue(row, columnMap, 'HoursPerDay') ??
          _getDoubleValue(row, columnMap, 'Usage_Hours_per_Day') ??
          0.0;

      // If hoursPerDay is missing, try to calculate from power and energy
      if (hoursPerDay == 0.0) {
        final power =
            _getDoubleValue(row, columnMap, 'Power') ??
            _getDoubleValue(row, columnMap, 'Power(W)') ??
            0.0;
        final energyKwh =
            _getDoubleValue(row, columnMap, 'Energy(kWh)') ??
            _getDoubleValue(row, columnMap, 'Energy_Consumption(kWh)') ??
            _getDoubleValue(row, columnMap, 'Energy') ??
            0.0;
        if (power > 0 && energyKwh > 0) {
          hoursPerDay =
              (energyKwh * 1000) / power / 30; // Approximate hours per day
        }
      }

      return PredictiveDataModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        month: _getStringValue(row, columnMap, 'Month') ?? '',
        appliance: _getStringValue(row, columnMap, 'Appliance') ?? '',
        voltage:
            _getDoubleValue(row, columnMap, 'Voltage') ??
            _getDoubleValue(row, columnMap, 'Average_Voltage(V)') ??
            0.0,
        current:
            _getDoubleValue(row, columnMap, 'Current') ??
            _getDoubleValue(row, columnMap, 'Average_Current(A)') ??
            0.0,
        power:
            _getDoubleValue(row, columnMap, 'Power') ??
            _getDoubleValue(row, columnMap, 'Power(W)') ??
            0.0,
        hoursPerDay: hoursPerDay,
        energyKwh:
            _getDoubleValue(row, columnMap, 'Energy(kWh)') ??
            _getDoubleValue(row, columnMap, 'Energy_Consumption(kWh)') ??
            _getDoubleValue(row, columnMap, 'Energy') ??
            0.0,
        rate:
            _getDoubleValue(row, columnMap, 'Rate') ??
            _getDoubleValue(row, columnMap, 'Power_Rate(₱/kWh)') ??
            0.0,
        cost:
            _getDoubleValue(row, columnMap, 'Cost') ??
            _getDoubleValue(row, columnMap, 'Estimated_Monthly_Cost(₱)') ??
            0.0,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to parse CSV row: $e');
    }
  }

  /// Create from JSON Map
  factory PredictiveDataModel.fromJson(Map<String, dynamic> json) {
    return PredictiveDataModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      month: json['month'] ?? '',
      appliance: json['appliance'] ?? '',
      voltage: (json['voltage'] ?? 0.0).toDouble(),
      current: (json['current'] ?? 0.0).toDouble(),
      power: (json['power'] ?? 0.0).toDouble(),
      hoursPerDay:
          (json['hoursPerDay'] ?? json['hours_per_day'] ?? 0.0).toDouble(),
      energyKwh: (json['energyKwh'] ?? json['energy_kwh'] ?? 0.0).toDouble(),
      rate: (json['rate'] ?? 0.0).toDouble(),
      cost: (json['cost'] ?? 0.0).toDouble(),
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  /// Create from Map
  factory PredictiveDataModel.fromMap(Map<String, dynamic> map) {
    return PredictiveDataModel.fromJson(map);
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'appliance': appliance,
      'voltage': voltage,
      'current': current,
      'power': power,
      'hoursPerDay': hoursPerDay,
      'energyKwh': energyKwh,
      'rate': rate,
      'cost': cost,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Convert to JSON
  String toJson() {
    return jsonEncode(toMap());
  }

  /// Create a copy with updated values
  PredictiveDataModel copyWith({
    String? id,
    String? month,
    String? appliance,
    double? voltage,
    double? current,
    double? power,
    double? hoursPerDay,
    double? energyKwh,
    double? rate,
    double? cost,
    DateTime? createdAt,
  }) {
    return PredictiveDataModel(
      id: id ?? this.id,
      month: month ?? this.month,
      appliance: appliance ?? this.appliance,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      power: power ?? this.power,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      energyKwh: energyKwh ?? this.energyKwh,
      rate: rate ?? this.rate,
      cost: cost ?? this.cost,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Validate model data
  bool isValid() {
    return month.isNotEmpty &&
        appliance.isNotEmpty &&
        energyKwh >= 0 &&
        rate >= 0 &&
        cost >= 0;
  }

  /// Get formatted cost
  String get formattedCost => '₱${cost.toStringAsFixed(2)}';

  /// Get formatted energy
  String get formattedEnergy => '${energyKwh.toStringAsFixed(2)} kWh';

  /// Get formatted rate
  String get formattedRate => '₱${rate.toStringAsFixed(2)}/kWh';

  /// Helper method to get string value from CSV row
  static String? _getStringValue(
    List<dynamic> row,
    Map<String, int> columnMap,
    String columnName,
  ) {
    final index = columnMap[columnName.toLowerCase()];
    if (index == null || index >= row.length) return null;
    return row[index].toString().trim();
  }

  /// Helper method to get double value from CSV row
  static double? _getDoubleValue(
    List<dynamic> row,
    Map<String, int> columnMap,
    String columnName,
  ) {
    final index = columnMap[columnName.toLowerCase()];
    if (index == null || index >= row.length) return null;
    final value = row[index];
    if (value == null || value.toString().isEmpty) return null;
    return double.tryParse(value.toString().trim().replaceAll(',', ''));
  }

  @override
  String toString() {
    return 'PredictiveDataModel(id: $id, month: $month, appliance: $appliance, energyKwh: $energyKwh, cost: $cost)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PredictiveDataModel &&
        other.id == id &&
        other.month == month &&
        other.appliance == appliance &&
        other.energyKwh == energyKwh;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        month.hashCode ^
        appliance.hashCode ^
        energyKwh.hashCode;
  }
}
