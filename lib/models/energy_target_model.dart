import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for energy targets and goals
class EnergyTargetModel {
  final double targetCost;
  final double targetKwh;
  final double alertThreshold;
  final double meterPrevious;
  final double meterPresent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EnergyTargetModel({
    required this.targetCost,
    required this.targetKwh,
    required this.alertThreshold,
    required this.meterPrevious,
    required this.meterPresent,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore document
  factory EnergyTargetModel.fromFirestore(Map<String, dynamic> data) {
    return EnergyTargetModel(
      targetCost: (data['target_cost'] ?? 0.0).toDouble(),
      targetKwh: (data['target_kwh'] ?? 0.0).toDouble(),
      alertThreshold: (data['alert_threshold'] ?? 80.0).toDouble(),
      meterPrevious: (data['meterPrevious'] ?? 0.0).toDouble(),
      meterPresent: (data['meterPresent'] ?? 0.0).toDouble(),
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'target_cost': targetCost,
      'target_kwh': targetKwh,
      'alert_threshold': alertThreshold,
      'meterPrevious': meterPrevious,
      'meterPresent': meterPresent,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create a copy with updated values
  EnergyTargetModel copyWith({
    double? targetCost,
    double? targetKwh,
    double? alertThreshold,
    double? meterPrevious,
    double? meterPresent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnergyTargetModel(
      targetCost: targetCost ?? this.targetCost,
      targetKwh: targetKwh ?? this.targetKwh,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      meterPrevious: meterPrevious ?? this.meterPrevious,
      meterPresent: meterPresent ?? this.meterPresent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate meter reading difference
  double get meterDifference => meterPresent - meterPrevious;

  /// Check if target is realistic
  bool get isRealisticTarget {
    return targetCost > 0 &&
        targetKwh > 0 &&
        alertThreshold >= 10 &&
        alertThreshold <= 100;
  }

  /// Get formatted target cost
  String get formattedTargetCost => '₱${targetCost.toStringAsFixed(2)}';

  /// Get formatted target kWh
  String get formattedTargetKwh => '${targetKwh.toStringAsFixed(2)} kWh';

  /// Get formatted threshold
  String get formattedThreshold => '${alertThreshold.toStringAsFixed(0)}%';

  @override
  String toString() {
    return 'EnergyTargetModel(targetCost: $targetCost, targetKwh: $targetKwh, alertThreshold: $alertThreshold, meterPrevious: $meterPrevious, meterPresent: $meterPresent)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnergyTargetModel &&
        other.targetCost == targetCost &&
        other.targetKwh == targetKwh &&
        other.alertThreshold == alertThreshold &&
        other.meterPrevious == meterPrevious &&
        other.meterPresent == meterPresent;
  }

  @override
  int get hashCode {
    return targetCost.hashCode ^
        targetKwh.hashCode ^
        alertThreshold.hashCode ^
        meterPrevious.hashCode ^
        meterPresent.hashCode;
  }
}





