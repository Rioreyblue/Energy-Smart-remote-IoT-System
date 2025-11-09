import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exercise_app/services/chat_service.dart';
import 'package:exercise_app/services/chat_notification_service.dart';
import 'package:exercise_app/constants/constant.dart';

class TestChatSystem extends StatefulWidget {
  const TestChatSystem({super.key});

  @override
  State<TestChatSystem> createState() => _TestChatSystemState();
}

class _TestChatSystemState extends State<TestChatSystem> {
  final ChatService _chatService = ChatService();
  final ChatNotificationService _notificationService =
      ChatNotificationService();
  final TextEditingController _messageController = TextEditingController();
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _status = 'Initializing services...';
    });

    try {
      await _notificationService.initialize();
      await _chatService.initializeChat();

      setState(() {
        _status = 'Services initialized successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _sendTestMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final success = await _chatService.sendMessage(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Message sent!' : 'Failed to send message'),
          backgroundColor: success ? AppColor.accentGreen : AppColor.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat System Test'),
        backgroundColor: AppColor.accentGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat System Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Status: $_status'),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: _chatService,
                      builder: (context, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat ID: ${_chatService.currentChatId ?? 'None'}',
                            ),
                            Text('Messages: ${_chatService.messages.length}'),
                            Text('Is Loading: ${_chatService.isLoading}'),
                            if (_chatService.error != null)
                              Text('Error: ${_chatService.error}'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Message Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Test Message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a test message...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _sendTestMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.accentGreen,
                      ),
                      child: const Text('Send Message'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Messages List
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: _chatService,
                          builder: (context, child) {
                            if (_chatService.messages.isEmpty) {
                              return const Center(
                                child: Text('No messages yet'),
                              );
                            }

                            return ListView.builder(
                              itemCount: _chatService.messages.length,
                              itemBuilder: (context, index) {
                                final message = _chatService.messages[index];
                                final isCurrentUser =
                                    message.senderId ==
                                    FirebaseAuth.instance.currentUser?.uid;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isCurrentUser
                                            ? AppColor.accentGreen.withAlpha(26)
                                            : Colors.grey.withAlpha(26),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isCurrentUser ? 'You' : 'Support',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(message.text),
                                      const SizedBox(height: 4),
                                      Text(
                                        message.timestamp.toString(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _initializeServices,
                    child: const Text('🔄 Refresh'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _chatService.clear(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.accentRed,
                    ),
                    child: const Text('🗑️ Clear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
