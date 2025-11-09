import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message_v2.dart';
import '../models/chat_thread.dart';
import '../utils/app_logger.dart';
import 'cloudinary_service.dart';

/// Service for managing chat functionality
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _conversationSubscription;

  // Current state
  String? _currentChatId;
  List<ChatMessageV2> _messages = [];
  ChatThread? _currentConversation;
  bool _isLoading = false;
  String? _error;
  final Map<String, String?> _userPhotoUrlCache = {};
  final Map<String, String?> _userEmailCache = {};
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Getters
  String? get currentChatId => _currentChatId;
  List<ChatMessageV2> get messages => _messages;
  ChatThread? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize chat for current user
  Future<void> initializeChat() async {
    final user = _auth.currentUser;
    if (user == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find or create conversation
      await _findOrCreateConversation(user.uid);

      // Start listening to messages
      if (_currentChatId != null) {
        _startListeningToMessages();
      }
    } catch (e) {
      _error = e.toString();
      AppLogger.e('[ChatService] ❌ [ChatService] Error initializing chat: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Find existing conversation or create new one
  Future<void> _findOrCreateConversation(String userId) async {
    try {
      // Look for existing conversation
      final query =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: userId)
              .where('status', isEqualTo: 'active')
              .orderBy('lastMessageTime', descending: true)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        // Use existing conversation
        final doc = query.docs.first;
        _currentChatId = doc.id;
        _currentConversation = ChatThread.fromMap(doc.id, doc.data());
        AppLogger.i(
          '[ChatService] ✅ [ChatService] Found existing conversation: $_currentChatId',
        );
      } else {
        // Create new conversation
        await _createNewConversation(userId);
      }
    } catch (e) {
      AppLogger.e(
        '[ChatService] ❌ [ChatService] Error finding conversation: $e',
      );
      rethrow;
    }
  }

  /// Get user photoUrl from Firestore (cached)
  Future<String?> getUserPhotoUrl(String userId) async {
    if (_userPhotoUrlCache.containsKey(userId))
      return _userPhotoUrlCache[userId];
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      String? url;
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          if (data['photoUrl'] is String) {
            url = data['photoUrl'] as String?;
          } else if (data['profile'] is Map<String, dynamic>) {
            url =
                (data['profile'] as Map<String, dynamic>)['photoUrl']
                    as String?;
          } else if (data['profilePhotoUrl'] is String) {
            url = data['profilePhotoUrl'] as String?;
          }
        }
      }
      // If no photo in Firestore, try to get from Firebase Auth
      if (url == null || url.isEmpty) {
        final user = _auth.currentUser;
        if (user?.uid == userId && user?.photoURL != null) {
          url = user!.photoURL;
        }
      }
      _userPhotoUrlCache[userId] = url;
      return url;
    } catch (e) {
      AppLogger.e('[ChatService] Error getting user photo: $e');
      return null;
    }
  }

  /// Get user email from Firestore or Auth (cached)
  Future<String?> getUserEmail(String userId) async {
    if (_userEmailCache.containsKey(userId)) return _userEmailCache[userId];
    try {
      // First try Firestore
      final doc = await _firestore.collection('users').doc(userId).get();
      String? email;
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          if (data['email'] is String) {
            email = data['email'] as String?;
          } else if (data['profile'] is Map<String, dynamic>) {
            email =
                (data['profile'] as Map<String, dynamic>)['email'] as String?;
          }
        }
      }
      // If no email in Firestore, try Firebase Auth
      if (email == null || email.isEmpty) {
        final user = _auth.currentUser;
        if (user?.uid == userId && user?.email != null) {
          email = user!.email;
        }
      }
      _userEmailCache[userId] = email;
      return email;
    } catch (e) {
      AppLogger.e('[ChatService] Error getting user email: $e');
      return null;
    }
  }

  /// Unsend a message (mark as unsent via metadata)
  Future<bool> unsendMessage(String messageId) async {
    if (_currentChatId == null) return false;
    try {
      await _firestore
          .collection('chats')
          .doc(_currentChatId!)
          .collection('messages')
          .doc(messageId)
          .update({
            'metadata': {'unsent': true},
            'text': '[Message unsent]',
          });
      AppLogger.i('[ChatService] Message unsent: $messageId');
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.e('[ChatService] Error unsending message: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete a message (remove from Firestore)
  Future<bool> deleteMessage(String messageId) async {
    if (_currentChatId == null) return false;
    try {
      await _firestore
          .collection('chats')
          .doc(_currentChatId!)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Create new conversation
  Future<void> _createNewConversation(String userId) async {
    try {
      final chatId = _uuid.v4();
      final now = Timestamp.now();

      // Create conversation document
      final conversation = ChatThread(
        id: chatId,
        participants: [userId, 'admin'],
        createdAt: now,
        lastMessageTime: now,
        lastMessage: null,
        subject: null,
        status: 'active',
        priority: 'normal',
        unreadCount: {userId: 0, 'admin': 0},
      );

      await _firestore
          .collection('chats')
          .doc(chatId)
          .set(conversation.toMap());

      _currentChatId = chatId;
      _currentConversation = conversation;

      AppLogger.i(
        '[ChatService] ✅ [ChatService] Created new conversation: $chatId',
      );
    } catch (e) {
      AppLogger.e(
        '[ChatService] ❌ [ChatService] Error creating conversation: $e',
      );
      rethrow;
    }
  }

  /// Start listening to messages
  void _startListeningToMessages() {
    if (_currentChatId == null) return;

    _messagesSubscription = _firestore
        .collection('chats')
        .doc(_currentChatId!)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) {
            _messages =
                snapshot.docs
                    .map((doc) => ChatMessageV2.fromMap(doc.id, doc.data()))
                    .toList();
            notifyListeners();
            print(
              '📨 [ChatService] Messages updated: ${_messages.length} messages',
            );
          },
          onError: (error) {
            _error = error.toString();
            AppLogger.e(
              '[ChatService] ❌ [ChatService] Error listening to messages: $error',
            );
            notifyListeners();
          },
        );
  }

  /// Send a message
  Future<bool> sendMessage(String text) async {
    final user = _auth.currentUser;
    if (user == null || _currentChatId == null) {
      _error = 'User not authenticated or no active chat';
      notifyListeners();
      return false;
    }

    try {
      final messageId = _uuid.v4();
      final now = Timestamp.now();

      final message = ChatMessageV2(
        id: messageId,
        chatId: _currentChatId!,
        senderId: user.uid,
        text: text,
        timestamp: now,
        type: 'text',
        status: 'sent',
      );

      // Add message to Firestore
      await _firestore
          .collection('chats')
          .doc(_currentChatId!)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      // Update conversation with last message
      // Note: Unread count is incremented by Cloud Function to prevent race conditions
      await _firestore.collection('chats').doc(_currentChatId!).update({
        'lastMessage': text,
        'lastMessageTime': now,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.i('[ChatService] ✅ [ChatService] Message sent: $text');
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.e('[ChatService] ❌ [ChatService] Error sending message: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send an image message
  Future<bool> sendImageMessage(
    File imageFile, {
    Function(double)? onUploadProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _currentChatId == null) {
      _error = 'User not authenticated or no active chat';
      notifyListeners();
      return false;
    }

    try {
      // Upload image to Cloudinary
      final imageUrl = await _cloudinaryService.uploadImage(
        imageFile,
        folder: 'chat_images',
        onProgress: onUploadProgress,
      );

      if (imageUrl == null) {
        _error = 'Failed to upload image';
        notifyListeners();
        return false;
      }

      final messageId = _uuid.v4();
      final now = Timestamp.now();

      final message = ChatMessageV2(
        id: messageId,
        chatId: _currentChatId!,
        senderId: user.uid,
        text: 'Image',
        timestamp: now,
        type: 'image',
        status: 'sent',
        attachments: [
          {
            'type': 'image',
            'url': imageUrl,
            'name': imageFile.path.split('/').last,
          },
        ],
      );

      // Add message to Firestore
      await _firestore
          .collection('chats')
          .doc(_currentChatId!)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      // Update conversation with last message
      await _firestore.collection('chats').doc(_currentChatId!).update({
        'lastMessage': '📷 Image',
        'lastMessageTime': now,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.i('[ChatService] ✅ Image message sent: $imageUrl');
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.e('[ChatService] ❌ Error sending image message: $e');
      notifyListeners();
      return false;
    }
  }

  /// Mark conversation as read
  Future<void> markAsRead() async {
    if (_currentChatId == null) return;

    try {
      await _firestore.collection('chats').doc(_currentChatId!).update({
        'lastReadByUser': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      AppLogger.e('[ChatService] ❌ [ChatService] Error marking as read: $e');
    }
  }

  /// Get conversation info
  Future<ChatThread?> getConversation(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();

      if (doc.exists) {
        return ChatThread.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      AppLogger.e(
        '[ChatService] ❌ [ChatService] Error getting conversation: $e',
      );
      return null;
    }
  }

  /// Check if user has unread messages
  Future<bool> hasUnreadMessages() async {
    final user = _auth.currentUser;
    if (user == null || _currentChatId == null) return false;

    try {
      final doc =
          await _firestore.collection('chats').doc(_currentChatId!).get();

      if (doc.exists) {
        final data = doc.data()!;
        final lastReadByUser = data['lastReadByUser'] as Timestamp?;
        final lastMessageTime = data['lastMessageTime'] as Timestamp?;

        if (lastMessageTime != null && lastReadByUser != null) {
          return lastMessageTime.toDate().isAfter(lastReadByUser.toDate());
        }
      }
      return false;
    } catch (e) {
      AppLogger.e(
        '[ChatService] ❌ [ChatService] Error checking unread messages: $e',
      );
      return false;
    }
  }

  /// Refresh chat data
  Future<void> refresh() async {
    await initializeChat();
  }

  /// Clear chat data
  void clear() {
    _messagesSubscription?.cancel();
    _conversationSubscription?.cancel();
    _currentChatId = null;
    _messages.clear();
    _currentConversation = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _conversationSubscription?.cancel();
    super.dispose();
  }
}
