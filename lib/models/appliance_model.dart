import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ApplianceModel {
  final String id;
  final String icon;
  final bool isOn;
  final double kwh;
  final String name;
  final String? startTime;
  final int? totalUsageTime;
  final int? watts;
  final String? lastUpdated;
  final double? voltage;
  final double? current;

  ApplianceModel({
    required this.id,
    required this.icon,
    required this.isOn,
    required this.kwh,
    required this.name,
    this.startTime,
    this.totalUsageTime,
    this.watts,
    this.lastUpdated,
    this.voltage,
    this.current,
  });

  factory ApplianceModel.fromMap(String id, Map<String, dynamic> data) {
    return ApplianceModel(
      id: id,
      icon: data['icon'] ?? 'Iconsax.lamp',
      isOn: data['isOn'] ?? false,
      kwh: (data['kwh'] ?? 0.0).toDouble(),
      name: data['name'] ?? 'Unknown Device',
      startTime: data['startTime'],
      totalUsageTime: data['totalUsageTime'],
      watts: data['watts'],
      lastUpdated: data['lastUpdated'],
      voltage:
          data['voltage'] != null ? (data['voltage'] as num).toDouble() : null,
      current:
          data['current'] != null ? (data['current'] as num).toDouble() : null,
    );
  }

  factory ApplianceModel.fromRealtimeDB(String id, Map<String, dynamic> data) {
    return ApplianceModel(
      id: id,
      icon: data['icon'] ?? 'Iconsax.lamp',
      isOn: data['isOn'] ?? false,
      kwh: (data['kwh'] ?? 0.0).toDouble(),
      name: data['name'] ?? 'Unknown Device',
      startTime: data['startTime'],
      totalUsageTime: data['totalUsageTime'],
      watts: data['watts'],
      lastUpdated: data['lastUpdated'],
      voltage:
          data['voltage'] != null ? (data['voltage'] as num).toDouble() : null,
      current:
          data['current'] != null ? (data['current'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'icon': icon,
      'isOn': isOn,
      'kwh': kwh,
      'name': name,
      'startTime': startTime,
      'totalUsageTime': totalUsageTime,
      'watts': watts,
      'lastUpdated': lastUpdated,
      'voltage': voltage,
      'current': current,
    };
  }

  ApplianceModel copyWith({
    String? id,
    String? icon,
    bool? isOn,
    double? kwh,
    String? name,
    String? startTime,
    int? totalUsageTime,
    int? watts,
    String? lastUpdated,
    double? voltage,
    double? current,
  }) {
    return ApplianceModel(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      isOn: isOn ?? this.isOn,
      kwh: kwh ?? this.kwh,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      totalUsageTime: totalUsageTime ?? this.totalUsageTime,
      watts: watts ?? this.watts,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
    );
  }

  // Calculate cost based on kWh and rate per kWh
  double calculateCost(double ratePerKwh) {
    return kwh * ratePerKwh;
  }

  // Format cost as currency
  String formatCost(double ratePerKwh) {
    final cost = calculateCost(ratePerKwh);
    return '₱${cost.toStringAsFixed(2)}';
  }

  // Format kWh display
  String formatKwh() {
    return '${kwh.toStringAsFixed(2)} kWh';
  }

  // Format watts display
  String formatWatts() {
    return '${watts ?? 0}W';
  }

  // Format usage time
  String formatUsageTime() {
    if (totalUsageTime == null) return '0h 0m';
    final hours = totalUsageTime! ~/ 3600;
    final minutes = (totalUsageTime! % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  // Calculate current session duration if appliance is on
  Duration? getCurrentSessionDuration() {
    if (!isOn || startTime == null) return null;
    final start = DateTime.tryParse(startTime!);
    if (start == null) return null;
    return DateTime.now().difference(start);
  }

  // Get current session cost
  double getCurrentSessionCost(double ratePerKwh) {
    if (!isOn || startTime == null || watts == null) return 0.0;
    final duration = getCurrentSessionDuration();
    if (duration == null) return 0.0;
    final hours = duration.inSeconds / 3600.0;
    final sessionKwh = (watts! * hours) / 1000.0;
    return sessionKwh * ratePerKwh;
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
      case 'Iconsax.socket':
        // There is no explicit 'socket' icon in some Iconsax versions; use electricity as closest match
        return Iconsax.electricity;
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
