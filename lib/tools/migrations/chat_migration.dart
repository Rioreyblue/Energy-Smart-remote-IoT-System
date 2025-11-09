import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time migration script to backfill chat fields to the new schema.
/// Run from a debug page or isolate in app startup guarded by an admin/dev flag.
Future<void> runChatMigration() async {
  final firestore = FirebaseFirestore.instance;
  final chatsCol = firestore.collection('chats');

  final chats = await chatsCol.get();
  for (final chatDoc in chats.docs) {
    final data = chatDoc.data();

    // Backfill createdAt
    final createdAt = data['createdAt'] as Timestamp? ?? Timestamp.now();

    // lastMessageTime must be present
    final lastMessageTime = data['lastMessageTime'] as Timestamp? ?? createdAt;

    // status default
    final status = data['status'] ?? 'active';

    // priority default
    final priority = data['priority'] ?? 'normal';

    // unreadCount map
    Map<String, int> unread = {};
    if (data['unreadCount'] is Map) {
      unread = Map<String, int>.from(
        (data['unreadCount'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      );
    }

    // Ensure participants exists
    final participants = List<String>.from(
      data['participants'] ?? const <String>[],
    );

    await chatDoc.reference.update({
      'createdAt': createdAt,
      'lastMessageTime': lastMessageTime,
      'status': status,
      'priority': priority,
      'unreadCount': unread,
      'participants': participants,
    });

    // Messages subcollection migration
    final msgs = await chatDoc.reference.collection('messages').get();
    for (final m in msgs.docs) {
      final md = m.data();
      final ts = md['timestamp'] as Timestamp? ?? Timestamp.now();
      final chatId = md['chatId'] ?? chatDoc.id;
      final type = md['type'] ?? 'text';
      final status = md['status'] ?? 'sent';
      final attachments = List<Map<String, dynamic>>.from(
        md['attachments'] ?? const [],
      );

      await m.reference.update({
        'timestamp': ts,
        'chatId': chatId,
        'type': type,
        'status': status,
        'attachments': attachments,
      });
    }
  }
}
