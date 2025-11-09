import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat conversation model for Firestore
class ChatConversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversation.fromMap(Map<String, dynamic> data, String id) {
    return ChatConversation(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime:
          data['lastMessageTime'] != null
              ? (data['lastMessageTime'] as Timestamp).toDate()
              : null,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Get the other participant (admin) ID
  String? getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : '',
    );
  }

  /// Check if user is participant
  bool isParticipant(String userId) {
    return participants.contains(userId);
  }
}



