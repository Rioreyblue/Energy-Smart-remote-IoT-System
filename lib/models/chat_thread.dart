import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final Timestamp lastMessageTime;
  final Timestamp createdAt;
  final Map<String, int> unreadCount;
  final String? subject;
  final String status; // active | archived | closed
  final String priority; // low | normal | high | urgent
  final String? assignedAdminId;
  final Map<String, bool>? typing;
  final String? userName;
  final String? userEmail;
  final String? userPhotoUrl;

  ChatThread({
    required this.id,
    required this.participants,
    required this.lastMessageTime,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = const {},
    this.subject,
    this.status = 'active',
    this.priority = 'normal',
    this.assignedAdminId,
    this.typing,
    this.userName,
    this.userEmail,
    this.userPhotoUrl,
  });

  factory ChatThread.fromMap(String id, Map<String, dynamic> data) {
    return ChatThread(
      id: id,
      participants: List<String>.from(data['participants'] ?? const <String>[]),
      lastMessage: data['lastMessage'],
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp? ?? Timestamp.now()),
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            {},
      ),
      subject: data['subject'],
      status: data['status'] ?? 'active',
      priority: data['priority'] ?? 'normal',
      assignedAdminId: data['assignedAdminId'],
      typing:
          data['typing'] != null
              ? Map<String, bool>.from(data['typing'])
              : null,
      userName: data['userName'],
      userEmail: data['userEmail'],
      userPhotoUrl: data['userPhotoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'createdAt': createdAt,
      'unreadCount': unreadCount,
      'subject': subject,
      'status': status,
      'priority': priority,
      'assignedAdminId': assignedAdminId,
      'typing': typing,
      'userName': userName,
      'userEmail': userEmail,
      'userPhotoUrl': userPhotoUrl,
    };
  }
}
