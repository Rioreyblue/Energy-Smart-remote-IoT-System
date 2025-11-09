import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// Chat message model for Firestore
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String? imageUrl;
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.imageUrl,
    this.type = MessageType.text,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type'] ?? 'text'}',
        orElse: () => MessageType.text,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'type': type.toString().split('.').last,
    };
  }

  /// Convert to flutter_chat_types message
  types.TextMessage toFlutterChatMessage(String currentUserId) {
    return types.TextMessage(
      id: id,
      author: types.User(
        id: senderId,
        firstName: senderId == currentUserId ? 'You' : 'Support',
      ),
      text: text,
      createdAt: timestamp.millisecondsSinceEpoch,
    );
  }
}

enum MessageType { text, image, file }



