import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ApplianceModel {
  final String uid;
  final String icon;
  final bool isOn;
  final double kWh;
  final String name;
  final String startTime;
  final int totalUsageTime;
  final int watts;

  ApplianceModel({
    required this.uid,
    required this.icon,
    required this.isOn,
    required this.kWh,
    required this.name,
    required this.startTime,
    required this.totalUsageTime,
    required this.watts,
  });

  factory ApplianceModel.fromMap(String uid, Map<String, dynamic> data) {
    return ApplianceModel(
      uid: uid,
      icon: data['icon'] ?? 'Iconsax.lamp',
      isOn: data['isOn'] ?? false,
      kWh: (data['kWh'] ?? 0.0).toDouble(),
      name: data['name'] ?? 'Unknown Device',
      startTime: data['startTime'] ?? '',
      totalUsageTime: data['totalUsageTime'] ?? 0,
      watts: data['watts'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'isOn': isOn,
      'kWh': kWh,
      'name': name,
      'startTime': startTime,
      'totalUsageTime': totalUsageTime,
      'watts': watts,
    };
  }

  ApplianceModel copyWith({
    String? uid,
    String? icon,
    bool? isOn,
    double? kWh,
    String? name,
    String? startTime,
    int? totalUsageTime,
    int? watts,
  }) {
    return ApplianceModel(
      uid: uid ?? this.uid,
      icon: icon ?? this.icon,
      isOn: isOn ?? this.isOn,
      kWh: kWh ?? this.kWh,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      totalUsageTime: totalUsageTime ?? this.totalUsageTime,
      watts: watts ?? this.watts,
    );
  }

  // Calculate cost based on kWh and rate per kWh
  double calculateCost(double ratePerKwh) {
    return kWh * ratePerKwh;
  }

  // Format cost as currency
  String formatCost(double ratePerKwh) {
    final cost = calculateCost(ratePerKwh);
    return '₱${cost.toStringAsFixed(4)}';
  }

  // Format kWh display
  String formatKwh() {
    return '${kWh.toStringAsFixed(2)} kWh';
  }

  // Format watts display
  String formatWatts() {
    return '${watts}W';
  }

  // Get icon data from string
  IconData getIconData() {
    switch (icon) {
      case 'Iconsax.lamp':
        return Iconsax.lamp;
      case 'Iconsax.lamp_1':
        return Iconsax.lamp_1;
      case 'Iconsax.lamp_charge':
        return Iconsax.lamp_charge;
      case 'Iconsax.coffee':
        return Iconsax.coffee;
      case 'Iconsax.air_conditioner':
        return Iconsax.wind;
      case 'Iconsax.water':
        return Iconsax.drop;
      case 'Iconsax.monitor':
        return Iconsax.monitor;
      case 'Iconsax.fan':
        return Iconsax.wind;
      case 'Iconsax.refresh':
        return Iconsax.refresh;
      case 'Iconsax.home':
        return Iconsax.home;
      default:
        return Iconsax.lamp;
    }
  }
}

// Energy metadata model for Firestore
class EnergyMetadata {
  final String monthId;
  final double totalConsumption;
  final double totalCost;
  final double targetCost;
  final DateTime timestamp;
  final Map<String, DeviceLog> deviceLogs;

  EnergyMetadata({
    required this.monthId,
    required this.totalConsumption,
    required this.totalCost,
    required this.targetCost,
    required this.timestamp,
    this.deviceLogs = const {},
  });

  factory EnergyMetadata.fromMap(String monthId, Map<String, dynamic> data) {
    final logs = data['deviceLogs'] as Map<String, dynamic>? ?? {};
    return EnergyMetadata(
      monthId: monthId,
      totalConsumption: (data['totalConsumption'] ?? 0.0).toDouble(),
      totalCost: (data['totalCost'] ?? 0.0).toDouble(),
      targetCost: (data['targetCost'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(
        data['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      deviceLogs: logs.map(
        (key, value) =>
            MapEntry(key, DeviceLog.fromMap(Map<String, dynamic>.from(value))),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalConsumption': totalConsumption,
      'totalCost': totalCost,
      'targetCost': targetCost,
      'timestamp': timestamp.toIso8601String(),
      'deviceLogs': deviceLogs.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }
}

// Device log model for Firestore
class DeviceLog {
  final double usageDuration;
  final double kWhUsed;
  final double cost;
  final DateTime updatedAt;

  DeviceLog({
    required this.usageDuration,
    required this.kWhUsed,
    required this.cost,
    required this.updatedAt,
  });

  factory DeviceLog.fromMap(Map<String, dynamic> data) {
    return DeviceLog(
      usageDuration: (data['usageDuration'] ?? 0.0).toDouble(),
      kWhUsed: (data['kWhUsed'] ?? 0.0).toDouble(),
      cost: (data['cost'] ?? 0.0).toDouble(),
      updatedAt: DateTime.parse(
        data['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usageDuration': usageDuration,
      'kWhUsed': kWhUsed,
      'cost': cost,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
