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
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing chat functionality
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();
  final NotificationService _notificationService = NotificationService();
  static const String _kChatLastAlertPrefix = 'chat_last_alert_';

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
  String? _defaultAdminId;
  bool _initialMessagesLoaded = false;

  // Getters
  String? get currentChatId => _currentChatId;
  List<ChatMessageV2> get messages => _messages;
  ChatThread? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get defaultAdminId => _defaultAdminId;

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
      await _ensureDefaultAdminId();
      if (_defaultAdminId == null) {
        throw StateError('No admin available for chat support');
      }

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

  Future<void> _ensureDefaultAdminId() async {
    if (_defaultAdminId != null) return;

    try {
      QuerySnapshot<Map<String, dynamic>> query =
          await _firestore
              .collection('admins')
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        query = await _firestore.collection('admins').limit(1).get();
      }

      if (query.docs.isNotEmpty) {
        _defaultAdminId = query.docs.first.id;
        AppLogger.i('[ChatService] ✅ Resolved default admin: $_defaultAdminId');
      } else {
        AppLogger.e('[ChatService] ❌ No admin document found in Firestore');
      }
    } catch (e) {
      AppLogger.e('[ChatService] ❌ Error resolving admin ID: $e');
      rethrow;
    }
  }

  /// Find existing conversation or create new one
  Future<void> _findOrCreateConversation(String userId) async {
    try {
      // Prefer conversation that already has clientId set
      final clientQuery =
          await _firestore
              .collection('chats')
              .where('clientId', isEqualTo: userId)
              .limit(1)
              .get();

      if (clientQuery.docs.isNotEmpty) {
        final doc = clientQuery.docs.first;
        await _useExistingConversation(doc.id, doc.data(), userId);
        AppLogger.i(
          '[ChatService] ✅ Found existing conversation by clientId: $_currentChatId',
        );
        return;
      }

      // Check deterministic support document id in case it was previously created
      final deterministicRef = _firestore
          .collection('chats')
          .doc('support_$userId');
      final deterministicSnap = await deterministicRef.get();
      if (deterministicSnap.exists) {
        await _useExistingConversation(
          deterministicSnap.id,
          deterministicSnap.data() as Map<String, dynamic>,
          userId,
        );
        AppLogger.i(
          '[ChatService] ✅ Found deterministic support conversation: $_currentChatId',
        );
        return;
      }

      // Legacy fallback: look for conversations without clientId but containing the user
      final legacyQuery =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: userId)
              .limit(1)
              .get();

      if (legacyQuery.docs.isNotEmpty) {
        final doc = legacyQuery.docs.first;
        await _useExistingConversation(doc.id, doc.data(), userId);
        AppLogger.i(
          '[ChatService] ✅ Found legacy conversation: $_currentChatId',
        );
        return;
      }

      // Create new conversation if none found
      await _createNewConversation(userId);
    } catch (e) {
      AppLogger.e(
        '[ChatService] ❌ [ChatService] Error finding conversation: $e',
      );
      rethrow;
    }
  }

  /// Get user photoUrl from Firestore (cached)
  Future<String?> getUserPhotoUrl(String userId) async {
    if (_userPhotoUrlCache.containsKey(userId)) {
      return _userPhotoUrlCache[userId];
    }
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

  Future<String?> _resolveDisplayName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final displayName = (data['displayName'] as String?)?.trim();
          if (displayName != null && displayName.isNotEmpty) return displayName;

          final firstName = (data['firstName'] as String?)?.trim() ?? '';
          final lastName = (data['lastName'] as String?)?.trim() ?? '';
          final fullName =
              [
                firstName,
                lastName,
              ].where((part) => part.isNotEmpty).join(' ').trim();
          if (fullName.isNotEmpty) return fullName;
        }
      }
    } catch (e) {
      AppLogger.e('[ChatService] Error resolving display name: $e');
    }
    final authUser = _auth.currentUser;
    if (authUser?.uid == userId) {
      final authDisplayName = authUser?.displayName?.trim();
      if (authDisplayName != null && authDisplayName.isNotEmpty) {
        return authDisplayName;
      }
      final email = authUser?.email;
      if (email != null && email.isNotEmpty) {
        return email.split('@').first;
      }
    }
    final email = await getUserEmail(userId);
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return null;
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
      final chatRef = _firestore.collection('chats').doc('support_$userId');
      final now = Timestamp.now();

      final userName = await _resolveDisplayName(userId);
      final userEmail = await getUserEmail(userId);
      final userPhotoUrl = await getUserPhotoUrl(userId);

      final conversation = ChatThread(
        id: chatRef.id,
        participants: [userId, _defaultAdminId!],
        clientId: userId,
        createdAt: now,
        lastMessageTime: now,
        lastMessage: null,
        subject: null,
        status: 'active',
        priority: 'normal',
        unreadCount: {userId: 0, _defaultAdminId!: 0},
        assignedAdminId: _defaultAdminId,
        userName: userName,
        userEmail: userEmail,
        userPhotoUrl: userPhotoUrl,
      );

      await chatRef.set(conversation.toMap());

      _currentChatId = chatRef.id;
      _currentConversation = conversation;

      AppLogger.i(
        '[ChatService] ✅ [ChatService] Created new conversation: ${chatRef.id}',
      );
    } catch (e) {
      AppLogger.e(
        '[ChatService] ❌ [ChatService] Error creating conversation: $e',
      );
      rethrow;
    }
  }

  Future<void> _ensureConversationMetadata(
    ChatThread conversation,
    String userId,
  ) async {
    final missingName =
        conversation.userName == null || conversation.userName!.trim().isEmpty;
    final missingEmail =
        conversation.userEmail == null ||
        conversation.userEmail!.trim().isEmpty;
    final missingPhoto =
        conversation.userPhotoUrl == null ||
        conversation.userPhotoUrl!.trim().isEmpty;

    final missingClientId =
        conversation.clientId == null || conversation.clientId!.trim().isEmpty;

    if (!missingName && !missingEmail && !missingPhoto && !missingClientId) {
      return;
    }

    final updates = <String, dynamic>{};

    if (missingName) {
      final resolvedName = await _resolveDisplayName(userId);
      if (resolvedName != null && resolvedName.trim().isNotEmpty) {
        updates['userName'] = resolvedName.trim();
      }
    }

    if (missingEmail) {
      final resolvedEmail = await getUserEmail(userId);
      if (resolvedEmail != null && resolvedEmail.trim().isNotEmpty) {
        updates['userEmail'] = resolvedEmail.trim();
      }
    }

    if (missingPhoto) {
      final resolvedPhoto = await getUserPhotoUrl(userId);
      if (resolvedPhoto != null && resolvedPhoto.trim().isNotEmpty) {
        updates['userPhotoUrl'] = resolvedPhoto.trim();
      }
    }

    if (missingClientId) {
      updates['clientId'] = userId;
    }

    if (updates.isEmpty) return;

    updates['updatedAt'] = FieldValue.serverTimestamp();

    try {
      await _firestore.collection('chats').doc(conversation.id).update(updates);
      final refreshed = await getConversation(conversation.id);
      if (refreshed != null) {
        _currentConversation = refreshed;
      }
    } catch (e) {
      AppLogger.e('[ChatService] ❌ Error updating conversation metadata: $e');
    }
  }

  Future<Map<String, Object?>> _buildUnreadCountUpdates(String senderId) async {
    if (_currentChatId == null) return {};

    List<String> participants = _currentConversation?.participants ?? [];

    if (participants.isEmpty) {
      try {
        final doc =
            await _firestore.collection('chats').doc(_currentChatId!).get();
        final data = doc.data();
        if (doc.exists && data != null) {
          participants = List<String>.from(data['participants'] ?? const []);
          _currentConversation = ChatThread.fromMap(doc.id, data);
        }
      } catch (e) {
        AppLogger.e(
          '[ChatService] ❌ Error loading participants for unread update: $e',
        );
      }
    }

    if (participants.isEmpty) return {};

    final updates = <String, Object?>{};

    for (final participant in participants) {
      final fieldPath = 'unreadCount.$participant';
      if (participant == senderId) {
        updates[fieldPath] = 0;
      } else {
        updates[fieldPath] = FieldValue.increment(1);
      }
    }

    return updates;
  }

  Future<void> _useExistingConversation(
    String docId,
    Map<String, dynamic> rawData,
    String userId,
  ) async {
    final data = Map<String, dynamic>.from(rawData);
    final missingClientId =
        (data['clientId'] as String?)?.trim().isEmpty ?? true;
    if (missingClientId) {
      data['clientId'] = userId;
      await _firestore.collection('chats').doc(docId).update({
        'clientId': userId,
      });
    }
    _currentChatId = docId;
    _currentConversation = ChatThread.fromMap(docId, data);
    await _ensureConversationMetadata(_currentConversation!, userId);
  }

  /// Start listening to messages
  void _startListeningToMessages() {
    if (_currentChatId == null) return;

    _initialMessagesLoaded = false;
    _messagesSubscription = _firestore
        .collection('chats')
        .doc(_currentChatId!)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) {
            final currentUserId = _auth.currentUser?.uid;
            _messages =
                snapshot.docs
                    .map((doc) => ChatMessageV2.fromMap(doc.id, doc.data()))
                    .toList();
            notifyListeners();
            AppLogger.d(
              '[ChatService] Messages updated: ${_messages.length} messages',
            );

            if (!_initialMessagesLoaded) {
              _initialMessagesLoaded = true;
              return;
            }

            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) continue;

              final data = change.doc.data();
              if (data == null) continue;

              final senderId = data['senderId'] as String?;
              if (senderId == null || senderId == currentUserId) continue;

              final metadata = data['metadata'] as Map<String, dynamic>?;
              if (metadata != null && metadata['unsent'] == true) continue;

              if ((data['type'] as String?) == 'system') continue;

              String senderName =
                  (data['senderName'] as String?)?.trim().isNotEmpty == true
                      ? (data['senderName'] as String).trim()
                      : 'Support';

              final messageType =
                  (data['type'] ?? 'text').toString().toLowerCase();
              String preview = (data['text'] ?? '').toString().trim();
              if (messageType == 'image') {
                preview = '📷 Image';
              } else if (messageType == 'file') {
                preview = '📎 Attachment';
              } else if (preview.isEmpty) {
                preview = 'You have a new message';
              } else if (preview.length > 80) {
                preview = '${preview.substring(0, 80)}…';
              }

              final chatId =
                  _currentChatId ??
                  change.doc.reference.parent.parent?.id ??
                  '';

              _notificationService.showChatMessageNotification(
                senderName: senderName,
                messagePreview: preview,
                chatId: chatId,
                messageId: change.doc.id,
              );
            }
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
      final senderId = user.uid;
      final messageId = _uuid.v4();
      final now = Timestamp.now();

      final senderName = await _resolveDisplayName(user.uid);
      final senderPhoto = await getUserPhotoUrl(user.uid);
      final senderEmail = await getUserEmail(user.uid);

      final message = ChatMessageV2(
        id: messageId,
        chatId: _currentChatId!,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhoto,
        senderEmail: senderEmail,
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

      final unreadUpdates = await _buildUnreadCountUpdates(user.uid);

      // Update conversation with last message and unread counters
      final conversationRef = _firestore
          .collection('chats')
          .doc(_currentChatId!);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(conversationRef);
        final snapshotData = snapshot.data() ?? {};
        final serverUnread = Map<String, dynamic>.from(
          (snapshotData['unreadCount'] as Map?) ?? {},
        );

        final Map<String, Object?> conversationUpdate = {
          'lastMessage': text,
          'lastMessageTime': now,
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        unreadUpdates.forEach((key, value) {
          if (!key.startsWith('unreadCount.')) {
            conversationUpdate[key] = value;
            return;
          }

          final participantId = key.substring('unreadCount.'.length);
          if (value is num) {
            conversationUpdate[key] = value;
            return;
          }

          final current = (serverUnread[participantId] as num?) ?? 0;
          if (participantId == senderId) {
            conversationUpdate[key] = 0;
          } else {
            conversationUpdate[key] = current + 1;
          }
        });

        transaction.update(conversationRef, conversationUpdate);
      });

      try {
        final updatedSnapshot = await conversationRef.get();
        if (updatedSnapshot.exists) {
          _currentConversation = ChatThread.fromMap(
            updatedSnapshot.id,
            updatedSnapshot.data()!,
          );
        }
      } catch (e) {
        AppLogger.w(
          '[ChatService] ⚠️ Unable to refresh conversation cache: $e',
        );
      }

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
      final senderId = user.uid;
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

      final senderName = await _resolveDisplayName(user.uid);
      final senderPhoto = await getUserPhotoUrl(user.uid);
      final senderEmail = await getUserEmail(user.uid);

      final message = ChatMessageV2(
        id: messageId,
        chatId: _currentChatId!,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhoto,
        senderEmail: senderEmail,
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

      final unreadUpdates = await _buildUnreadCountUpdates(user.uid);

      // Update conversation with last message and unread counters
      final conversationRef = _firestore
          .collection('chats')
          .doc(_currentChatId!);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(conversationRef);
        final snapshotData = snapshot.data() ?? {};
        final serverUnread = Map<String, dynamic>.from(
          (snapshotData['unreadCount'] as Map?) ?? {},
        );

        final Map<String, Object?> conversationUpdate = {
          'lastMessage': '📷 Image',
          'lastMessageTime': now,
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        unreadUpdates.forEach((key, value) {
          if (!key.startsWith('unreadCount.')) {
            conversationUpdate[key] = value;
            return;
          }

          final participantId = key.substring('unreadCount.'.length);
          if (value is num) {
            conversationUpdate[key] = value;
            return;
          }

          final current = (serverUnread[participantId] as num?) ?? 0;
          if (participantId == senderId) {
            conversationUpdate[key] = 0;
          } else {
            conversationUpdate[key] = current + 1;
          }
        });

        transaction.update(conversationRef, conversationUpdate);
      });

      try {
        final updatedSnapshot = await conversationRef.get();
        if (updatedSnapshot.exists) {
          _currentConversation = ChatThread.fromMap(
            updatedSnapshot.id,
            updatedSnapshot.data()!,
          );
        }
      } catch (e) {
        AppLogger.w(
          '[ChatService] ⚠️ Unable to refresh conversation cache: $e',
        );
      }

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
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      await _firestore.collection('chats').doc(_currentChatId!).update({
        'lastReadByUser': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount.$userId': 0,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kChatLastAlertPrefix${_currentChatId!}');
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
