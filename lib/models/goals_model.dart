import 'package:cloud_firestore/cloud_firestore.dart';

class GoalsModel {
  final String id;
  final double energyThreshold;
  final bool thresholdAlertEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  GoalsModel({
    required this.id,
    required this.energyThreshold,
    required this.thresholdAlertEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'energyThreshold': energyThreshold,
      'thresholdAlertEnabled': thresholdAlertEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore document
  factory GoalsModel.fromMap(String id, Map<String, dynamic> map) {
    return GoalsModel(
      id: id,
      energyThreshold: map['energyThreshold']?.toDouble() ?? 0.0,
      thresholdAlertEnabled: map['thresholdAlertEnabled'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Create a copy with updated values
  GoalsModel copyWith({
    String? id,
    double? energyThreshold,
    bool? thresholdAlertEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalsModel(
      id: id ?? this.id,
      energyThreshold: energyThreshold ?? this.energyThreshold,
      thresholdAlertEnabled:
          thresholdAlertEnabled ?? this.thresholdAlertEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MeterReadingModel {
  final String id;
  final double ratePerKwh;
  final double previousReading;
  final double presentReading;
  final DateTime startDate;
  final DateTime endDate;
  final double consumption;
  final double estimatedBill;
  final DateTime createdAt;

  MeterReadingModel({
    required this.id,
    required this.ratePerKwh,
    required this.previousReading,
    required this.presentReading,
    required this.startDate,
    required this.endDate,
    required this.consumption,
    required this.estimatedBill,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'ratePerKwh': ratePerKwh,
      'previousReading': previousReading,
      'presentReading': presentReading,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'consumption': consumption,
      'estimatedBill': estimatedBill,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory MeterReadingModel.fromMap(String id, Map<String, dynamic> map) {
    return MeterReadingModel(
      id: id,
      ratePerKwh: map['ratePerKwh']?.toDouble() ?? 0.0,
      previousReading: map['previousReading']?.toDouble() ?? 0.0,
      presentReading: map['presentReading']?.toDouble() ?? 0.0,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      consumption: map['consumption']?.toDouble() ?? 0.0,
      estimatedBill: map['estimatedBill']?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Create a copy with updated values
  MeterReadingModel copyWith({
    String? id,
    double? ratePerKwh,
    double? previousReading,
    double? presentReading,
    DateTime? startDate,
    DateTime? endDate,
    double? consumption,
    double? estimatedBill,
    DateTime? createdAt,
  }) {
    return MeterReadingModel(
      id: id ?? this.id,
      ratePerKwh: ratePerKwh ?? this.ratePerKwh,
      previousReading: previousReading ?? this.previousReading,
      presentReading: presentReading ?? this.presentReading,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      consumption: consumption ?? this.consumption,
      estimatedBill: estimatedBill ?? this.estimatedBill,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
