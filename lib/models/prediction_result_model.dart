import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/constant.dart';

/// Model for storing prediction results
class PredictionResultModel {
  final String id;
  final String month;
  final String? appliance;
  final double predictedKwh;
  final double predictedCost;
  final double confidence; // 0-100 percentage
  final String consumptionLevel; // 'low', 'average', 'high'
  final Map<String, dynamic>? applianceBreakdown; // kWh per appliance
  final Map<String, dynamic>? applianceCostBreakdown; // Cost per appliance
  final DateTime timestamp;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PredictionResultModel({
    required this.id,
    required this.month,
    this.appliance,
    required this.predictedKwh,
    required this.predictedCost,
    required this.confidence,
    this.consumptionLevel = 'average',
    this.applianceBreakdown,
    this.applianceCostBreakdown,
    required this.timestamp,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore document
  factory PredictionResultModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return PredictionResultModel(
      id: id,
      month: data['month'] ?? '',
      appliance: data['appliance'],
      predictedKwh:
          (data['predicted_kWh'] ?? data['predictedKwh'] ?? 0.0).toDouble(),
      predictedCost:
          (data['predicted_cost'] ?? data['predictedCost'] ?? 0.0).toDouble(),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      consumptionLevel:
          data['consumption_level'] ?? data['consumptionLevel'] ?? 'average',
      applianceBreakdown:
          data['applianceBreakdown'] as Map<String, dynamic>? ??
          data['appliance_breakdown'] as Map<String, dynamic>?,
      applianceCostBreakdown:
          data['applianceCostBreakdown'] as Map<String, dynamic>? ??
          data['appliance_cost_breakdown'] as Map<String, dynamic>?,
      timestamp:
          data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
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
      'month': month,
      'appliance': appliance,
      'predicted_kWh': predictedKwh,
      'predicted_cost': predictedCost,
      'confidence': confidence,
      'consumption_level': consumptionLevel,
      'applianceBreakdown': applianceBreakdown,
      'applianceCostBreakdown': applianceCostBreakdown,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Map
  factory PredictionResultModel.fromMap(Map<String, dynamic> map) {
    return PredictionResultModel(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      month: map['month'] ?? '',
      appliance: map['appliance'],
      predictedKwh: (map['predictedKwh'] ?? 0.0).toDouble(),
      predictedCost: (map['predictedCost'] ?? 0.0).toDouble(),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      consumptionLevel:
          map['consumptionLevel'] ?? map['consumption_level'] ?? 'average',
      applianceBreakdown: map['applianceBreakdown'] as Map<String, dynamic>?,
      applianceCostBreakdown:
          map['applianceCostBreakdown'] as Map<String, dynamic>?,
      timestamp:
          map['timestamp'] != null
              ? DateTime.parse(map['timestamp'])
              : DateTime.now(),
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'appliance': appliance,
      'predictedKwh': predictedKwh,
      'predictedCost': predictedCost,
      'confidence': confidence,
      'consumptionLevel': consumptionLevel,
      'applianceBreakdown': applianceBreakdown,
      'applianceCostBreakdown': applianceCostBreakdown,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  PredictionResultModel copyWith({
    String? id,
    String? month,
    String? appliance,
    double? predictedKwh,
    double? predictedCost,
    double? confidence,
    String? consumptionLevel,
    Map<String, dynamic>? applianceBreakdown,
    Map<String, dynamic>? applianceCostBreakdown,
    DateTime? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PredictionResultModel(
      id: id ?? this.id,
      month: month ?? this.month,
      appliance: appliance ?? this.appliance,
      predictedKwh: predictedKwh ?? this.predictedKwh,
      predictedCost: predictedCost ?? this.predictedCost,
      confidence: confidence ?? this.confidence,
      consumptionLevel: consumptionLevel ?? this.consumptionLevel,
      applianceBreakdown: applianceBreakdown ?? this.applianceBreakdown,
      applianceCostBreakdown:
          applianceCostBreakdown ?? this.applianceCostBreakdown,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted predicted cost
  String get formattedPredictedCost => '₱${predictedCost.toStringAsFixed(2)}';

  /// Get formatted predicted kWh
  String get formattedPredictedKwh => '${predictedKwh.toStringAsFixed(2)} kWh';

  /// Get formatted confidence percentage
  String get formattedConfidence => '${confidence.toStringAsFixed(1)}%';

  /// Get highest contributing appliance from breakdown
  String? get highestContributor {
    if (applianceBreakdown == null || applianceBreakdown!.isEmpty) {
      return null;
    }
    final sorted =
        applianceBreakdown!.entries.toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return sorted.isNotEmpty ? sorted.first.key : null;
  }

  /// Get percentage of highest contributor
  double? get highestContributorPercentage {
    if (applianceBreakdown == null || applianceBreakdown!.isEmpty) {
      return null;
    }
    final sorted =
        applianceBreakdown!.entries.toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    if (sorted.isEmpty || predictedKwh == 0) return null;
    final highestValue = sorted.first.value as num;
    return (highestValue / predictedKwh) * 100;
  }

  /// Get most costly appliance (highest cost)
  String? get mostCostlyAppliance {
    if (applianceCostBreakdown == null || applianceCostBreakdown!.isEmpty) {
      // Fallback to kWh breakdown if cost breakdown not available
      return highestContributor;
    }
    final sorted =
        applianceCostBreakdown!.entries.toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return sorted.isNotEmpty ? sorted.first.key : null;
  }

  /// Get least costly appliance (lowest cost)
  String? get leastCostlyAppliance {
    if (applianceCostBreakdown == null || applianceCostBreakdown!.isEmpty) {
      // Fallback to kWh breakdown if cost breakdown not available
      if (applianceBreakdown == null || applianceBreakdown!.isEmpty) {
        return null;
      }
      final sorted =
          applianceBreakdown!.entries.toList()
            ..sort((a, b) => (a.value as num).compareTo(b.value as num));
      return sorted.isNotEmpty ? sorted.first.key : null;
    }
    final sorted =
        applianceCostBreakdown!.entries.toList()
          ..sort((a, b) => (a.value as num).compareTo(b.value as num));
    return sorted.isNotEmpty ? sorted.first.key : null;
  }

  /// Get cost for a specific appliance
  double? getApplianceCost(String applianceId) {
    if (applianceCostBreakdown == null || applianceCostBreakdown!.isEmpty) {
      return null;
    }
    final cost = applianceCostBreakdown![applianceId];
    return cost != null ? (cost as num).toDouble() : null;
  }

  /// Get cost percentage for a specific appliance
  double? getApplianceCostPercentage(String applianceId) {
    final cost = getApplianceCost(applianceId);
    if (cost == null || predictedCost == 0) return null;
    return (cost / predictedCost) * 100;
  }

  /// Get most costly appliance details (name, cost, percentage)
  Map<String, dynamic>? getMostCostlyApplianceDetails() {
    final appliance = mostCostlyAppliance;
    if (appliance == null) return null;

    final cost = getApplianceCost(appliance);
    final percentage = getApplianceCostPercentage(appliance);
    final kwh =
        applianceBreakdown?[appliance] != null
            ? (applianceBreakdown![appliance] as num).toDouble()
            : null;

    return {
      'appliance': appliance,
      'cost': cost,
      'percentage': percentage,
      'kwh': kwh,
    };
  }

  /// Get least costly appliance details (name, cost, percentage)
  Map<String, dynamic>? getLeastCostlyApplianceDetails() {
    final appliance = leastCostlyAppliance;
    if (appliance == null) return null;

    final cost = getApplianceCost(appliance);
    final percentage = getApplianceCostPercentage(appliance);
    final kwh =
        applianceBreakdown?[appliance] != null
            ? (applianceBreakdown![appliance] as num).toDouble()
            : null;

    return {
      'appliance': appliance,
      'cost': cost,
      'percentage': percentage,
      'kwh': kwh,
    };
  }

  /// Get all appliances sorted by cost (highest first)
  List<Map<String, dynamic>> getAppliancesByCost() {
    if (applianceCostBreakdown == null || applianceCostBreakdown!.isEmpty) {
      return [];
    }

    final sorted =
        applianceCostBreakdown!.entries.toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return sorted.map((entry) {
      final appliance = entry.key;
      final cost = (entry.value as num).toDouble();
      final percentage = getApplianceCostPercentage(appliance);
      final kwh =
          applianceBreakdown?[appliance] != null
              ? (applianceBreakdown![appliance] as num).toDouble()
              : null;

      return {
        'appliance': appliance,
        'cost': cost,
        'percentage': percentage,
        'kwh': kwh,
      };
    }).toList();
  }

  /// Get color for consumption level
  Color get consumptionLevelColor {
    switch (consumptionLevel.toLowerCase()) {
      case 'low':
        return AppColor.lowConsumption;
      case 'high':
        return AppColor.highConsumption;
      case 'average':
      default:
        return AppColor.mediumConsumption;
    }
  }

  /// Get icon for consumption level
  IconData get consumptionLevelIcon {
    switch (consumptionLevel.toLowerCase()) {
      case 'low':
        return Icons.arrow_downward;
      case 'high':
        return Icons.arrow_upward;
      case 'average':
      default:
        return Icons.remove;
    }
  }

  @override
  String toString() {
    return 'PredictionResultModel(id: $id, month: $month, predictedKwh: $predictedKwh, predictedCost: $predictedCost, confidence: $confidence%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PredictionResultModel &&
        other.id == id &&
        other.month == month &&
        other.predictedKwh == predictedKwh &&
        other.predictedCost == predictedCost;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        month.hashCode ^
        predictedKwh.hashCode ^
        predictedCost.hashCode;
  }
}
