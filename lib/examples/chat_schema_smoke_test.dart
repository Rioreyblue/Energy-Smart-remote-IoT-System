import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatSchemaSmokeTest extends StatefulWidget {
  const ChatSchemaSmokeTest({super.key});
  @override
  State<ChatSchemaSmokeTest> createState() => _ChatSchemaSmokeTestState();
}

class _ChatSchemaSmokeTestState extends State<ChatSchemaSmokeTest> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _chatId;
  String _status = 'Idle';

  Future<void> _createChatAndSend() async {
    setState(() => _status = 'Running...');
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _status = 'No user signed in');
      return;
    }

    // Find or create chat
    final q =
        await _db
            .collection('chats')
            .where('participants', arrayContains: user.uid)
            .where('status', isEqualTo: 'active')
            .orderBy('lastMessageTime', descending: true)
            .limit(1)
            .get();

    final chatRef =
        q.docs.isNotEmpty
            ? q.docs.first.reference
            : _db.collection('chats').doc();

    if (q.docs.isEmpty) {
      await chatRef.set({
        'participants': [user.uid, 'admin'],
        'lastMessage': null,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {user.uid: 0, 'admin': 0},
        'subject': null,
        'status': 'active',
        'priority': 'normal',
        'assignedAdminId': null,
        'typing': {},
      });
    }

    final chatId = chatRef.id;
    _chatId = chatId;

    final msgRef = chatRef.collection('messages').doc();
    await msgRef.set({
      'id': msgRef.id,
      'chatId': chatId,
      'senderId': user.uid,
      'text': 'Hello from smoke test',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'status': 'sent',
      'attachments': [],
      'metadata': null,
      'replyToId': null,
    });

    await chatRef.update({
      'lastMessage': 'Hello from smoke test',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    setState(() => _status = 'Success. chatId=$_chatId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Schema Smoke Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createChatAndSend,
              child: const Text('Create chat and send a message'),
            ),
          ],
        ),
      ),
    );
  }
}

