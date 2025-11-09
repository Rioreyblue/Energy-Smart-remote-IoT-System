import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for energy trends data (daily, weekly, monthly)
class TrendsModel {
  final String id;
  final String period; // 'daily', 'weekly', 'monthly'
  final DateTime date;
  final double totalKwh;
  final double totalCost;
  final int totalUsageTime;
  final double? averageDailyKwh;
  final double? averageDailyCost;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrendsModel({
    required this.id,
    required this.period,
    required this.date,
    required this.totalKwh,
    required this.totalCost,
    required this.totalUsageTime,
    this.averageDailyKwh,
    this.averageDailyCost,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore document
  factory TrendsModel.fromFirestore(String id, Map<String, dynamic> data) {
    return TrendsModel(
      id: id,
      period: data['period'] ?? 'daily',
      date:
          data['date'] != null
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
      totalKwh: (data['totalKwh'] ?? 0.0).toDouble(),
      totalCost: (data['totalCost'] ?? 0.0).toDouble(),
      totalUsageTime: data['totalUsageTime'] ?? 0,
      averageDailyKwh: data['averageDailyKwh']?.toDouble(),
      averageDailyCost: data['averageDailyCost']?.toDouble(),
      metadata: data['metadata'] as Map<String, dynamic>?,
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
      'period': period,
      'date': Timestamp.fromDate(date),
      'totalKwh': totalKwh,
      'totalCost': totalCost,
      'totalUsageTime': totalUsageTime,
      'averageDailyKwh': averageDailyKwh,
      'averageDailyCost': averageDailyCost,
      'metadata': metadata,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create a copy with updated values
  TrendsModel copyWith({
    String? id,
    String? period,
    DateTime? date,
    double? totalKwh,
    double? totalCost,
    int? totalUsageTime,
    double? averageDailyKwh,
    double? averageDailyCost,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrendsModel(
      id: id ?? this.id,
      period: period ?? this.period,
      date: date ?? this.date,
      totalKwh: totalKwh ?? this.totalKwh,
      totalCost: totalCost ?? this.totalCost,
      totalUsageTime: totalUsageTime ?? this.totalUsageTime,
      averageDailyKwh: averageDailyKwh ?? this.averageDailyKwh,
      averageDailyCost: averageDailyCost ?? this.averageDailyCost,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted total cost
  String get formattedTotalCost => '₱${totalCost.toStringAsFixed(2)}';

  /// Get formatted total kWh
  String get formattedTotalKwh => '${totalKwh.toStringAsFixed(2)} kWh';

  /// Get formatted usage time
  String get formattedUsageTime {
    final hours = totalUsageTime ~/ 3600;
    final minutes = (totalUsageTime % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  /// Get formatted average daily kWh
  String get formattedAverageDailyKwh =>
      averageDailyKwh != null
          ? '${averageDailyKwh!.toStringAsFixed(2)} kWh'
          : 'N/A';

  /// Get formatted average daily cost
  String get formattedAverageDailyCost =>
      averageDailyCost != null
          ? '₱${averageDailyCost!.toStringAsFixed(2)}'
          : 'N/A';

  /// Get date string for display
  String get dateString {
    switch (period) {
      case 'daily':
        return '${date.day}/${date.month}/${date.year}';
      case 'weekly':
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        return '${startOfWeek.day}/${startOfWeek.month} - ${endOfWeek.day}/${endOfWeek.month}';
      case 'monthly':
        return '${date.month}/${date.year}';
      default:
        return date.toString();
    }
  }

  @override
  String toString() {
    return 'TrendsModel(id: $id, period: $period, date: $date, totalKwh: $totalKwh, totalCost: $totalCost, totalUsageTime: $totalUsageTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrendsModel &&
        other.id == id &&
        other.period == period &&
        other.date == date &&
        other.totalKwh == totalKwh &&
        other.totalCost == totalCost &&
        other.totalUsageTime == totalUsageTime;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        period.hashCode ^
        date.hashCode ^
        totalKwh.hashCode ^
        totalCost.hashCode ^
        totalUsageTime.hashCode;
  }
}

/// Model for activity data
class ActivityModel {
  final String id;
  final String type;
  final String message;
  final Map<String, dynamic>? meta;
  final DateTime timestamp;
  final String? userId;

  const ActivityModel({
    required this.id,
    required this.type,
    required this.message,
    this.meta,
    required this.timestamp,
    this.userId,
  });

  /// Create from Firestore document
  factory ActivityModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ActivityModel(
      id: id,
      type: data['type'] ?? 'unknown',
      message: data['message'] ?? '',
      meta: data['meta'] as Map<String, dynamic>?,
      timestamp:
          data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
      userId: data['userId'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'message': message,
      'meta': meta,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
    };
  }

  /// Get formatted timestamp
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  String toString() {
    return 'ActivityModel(id: $id, type: $type, message: $message, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityModel &&
        other.id == id &&
        other.type == type &&
        other.message == message &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^ type.hashCode ^ message.hashCode ^ timestamp.hashCode;
  }
}
