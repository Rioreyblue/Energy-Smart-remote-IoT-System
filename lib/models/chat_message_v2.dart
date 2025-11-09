import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageV2 {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final String type; // text | image | file | system
  final String status; // sending | sent | delivered | seen | error
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic>? metadata;
  final String? replyToId;

  ChatMessageV2({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = 'text',
    this.status = 'sent',
    this.attachments = const [],
    this.metadata,
    this.replyToId,
  });

  factory ChatMessageV2.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessageV2(
      id: id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp? ?? Timestamp.now()),
      type: data['type'] ?? 'text',
      status: data['status'] ?? 'sent',
      attachments: List<Map<String, dynamic>>.from(
        data['attachments'] ?? const [],
      ),
      metadata:
          data['metadata'] != null
              ? Map<String, dynamic>.from(data['metadata'])
              : null,
      replyToId: data['replyToId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'type': type,
      'status': status,
      'attachments': attachments,
      'metadata': metadata,
      'replyToId': replyToId,
    };
  }
}

