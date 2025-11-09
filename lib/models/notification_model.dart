import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for push notifications
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime timestamp;
  final String? userId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.timestamp,
    this.userId,
  });

  /// Create from Firestore document
  factory NotificationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationModel(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'general',
      data: data['data'] as Map<String, dynamic>?,
      isRead: data['isRead'] ?? false,
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
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
    };
  }

  /// Create a copy with updated values
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? timestamp,
    String? userId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
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

  /// Get notification icon based on type
  String get iconName {
    switch (type) {
      case 'threshold_reached':
        return 'warning';
      case 'goal_achieved':
        return 'check_circle';
      case 'rate_update':
        return 'money';
      case 'appliance_alert':
        return 'device';
      case 'energy_alert':
        return 'flash';
      case 'cost_alert':
        return 'wallet';
      default:
        return 'notification';
    }
  }

  /// Get notification color based on type
  String get colorName {
    switch (type) {
      case 'threshold_reached':
        return 'orange';
      case 'goal_achieved':
        return 'green';
      case 'rate_update':
        return 'blue';
      case 'appliance_alert':
        return 'red';
      case 'energy_alert':
        return 'yellow';
      case 'cost_alert':
        return 'orange';
      default:
        return 'grey';
    }
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, body: $body, type: $type, isRead: $isRead, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        other.type == type &&
        other.isRead == isRead &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        body.hashCode ^
        type.hashCode ^
        isRead.hashCode ^
        timestamp.hashCode;
  }
}

/// Model for FCM token management
class FCMTokenModel {
  final String token;
  final String? userId;
  final String? deviceId;
  final String? deviceType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsed;

  const FCMTokenModel({
    required this.token,
    this.userId,
    this.deviceId,
    this.deviceType,
    this.isActive = true,
    required this.createdAt,
    this.lastUsed,
  });

  /// Create from Firestore document
  factory FCMTokenModel.fromFirestore(String token, Map<String, dynamic> data) {
    return FCMTokenModel(
      token: token,
      userId: data['userId'],
      deviceId: data['deviceId'],
      deviceType: data['deviceType'],
      isActive: data['isActive'] ?? true,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      lastUsed:
          data['lastUsed'] != null
              ? (data['lastUsed'] as Timestamp).toDate()
              : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'deviceId': deviceId,
      'deviceType': deviceType,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUsed': lastUsed != null ? Timestamp.fromDate(lastUsed!) : null,
    };
  }

  /// Create a copy with updated values
  FCMTokenModel copyWith({
    String? token,
    String? userId,
    String? deviceId,
    String? deviceType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return FCMTokenModel(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  String toString() {
    return 'FCMTokenModel(token: $token, userId: $userId, deviceId: $deviceId, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FCMTokenModel &&
        other.token == token &&
        other.userId == userId &&
        other.deviceId == deviceId &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return token.hashCode ^
        userId.hashCode ^
        deviceId.hashCode ^
        isActive.hashCode;
  }
}
