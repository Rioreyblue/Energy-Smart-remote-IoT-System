import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Controller for tracking unread chat messages and displaying badge count
class ChatNotificationController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _unreadSubscription;
  int _unreadCount = 0;
  bool _isInitialized = false;

  String get _userId => _auth.currentUser?.uid ?? '';

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  /// Initialize controller and start listening for unread messages
  Future<void> initialize() async {
    if (_isInitialized || _userId.isEmpty) return;

    try {
      _isInitialized = true;
      await _loadUnreadCount();
      _startListeningForUnread();
      AppLogger.i('[ChatNotificationController] Initialized');
    } catch (e) {
      AppLogger.e('[ChatNotificationController] Error initializing: $e');
    }
  }

  /// Load initial unread count
  Future<void> _loadUnreadCount() async {
    try {
      if (_userId.isEmpty) return;

      // Get all conversations for this user
      final conversationsQuery =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: _userId)
              .where('status', isEqualTo: 'active')
              .get();

      int totalUnread = 0;

      for (final convDoc in conversationsQuery.docs) {
        final convData = convDoc.data();
        final unreadCounts =
            convData['unreadCount'] as Map<String, dynamic>? ?? {};
        final userUnread = (unreadCounts[_userId] as num?)?.toInt() ?? 0;
        totalUnread += userUnread;
      }

      _unreadCount = totalUnread;
      notifyListeners();
    } catch (e) {
      AppLogger.e(
        '[ChatNotificationController] Error loading unread count: $e',
      );
    }
  }

  /// Start listening for real-time unread count updates
  void _startListeningForUnread() {
    if (_userId.isEmpty) return;

    _unreadSubscription?.cancel();

    _unreadSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: _userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (snapshot) {
            _updateUnreadCount(snapshot);
          },
          onError: (error) {
            AppLogger.e('[ChatNotificationController] Error listening: $error');
          },
        );
  }

  /// Update unread count from Firestore snapshot
  void _updateUnreadCount(QuerySnapshot snapshot) {
    try {
      int totalUnread = 0;

      for (final convDoc in snapshot.docs) {
        final convData = convDoc.data() as Map<String, dynamic>;
        final unreadCounts =
            convData['unreadCount'] as Map<String, dynamic>? ?? {};
        final userUnread = (unreadCounts[_userId] as num?)?.toInt() ?? 0;
        totalUnread += userUnread;
      }

      if (_unreadCount != totalUnread) {
        _unreadCount = totalUnread;
        notifyListeners();
        AppLogger.i(
          '[ChatNotificationController] Unread count updated: $_unreadCount',
        );
      }
    } catch (e) {
      AppLogger.e(
        '[ChatNotificationController] Error updating unread count: $e',
      );
    }
  }

  /// Mark conversation as read
  Future<void> markAsRead(String chatId) async {
    if (_userId.isEmpty) return;

    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.$_userId': 0,
        'lastReadByUser': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Manually decrease unread count for immediate UI update
      final convDoc = await _firestore.collection('chats').doc(chatId).get();
      if (convDoc.exists) {
        final convData = convDoc.data() as Map<String, dynamic>;
        final unreadCounts =
            convData['unreadCount'] as Map<String, dynamic>? ?? {};
        final previousUnread = (unreadCounts[_userId] as num?)?.toInt() ?? 0;

        _unreadCount =
            (_unreadCount - previousUnread).clamp(0, double.infinity).toInt();
        notifyListeners();
      }

      AppLogger.i('[ChatNotificationController] Marked chat as read: $chatId');
    } catch (e) {
      AppLogger.e('[ChatNotificationController] Error marking as read: $e');
    }
  }

  /// Refresh unread count manually
  Future<void> refresh() async {
    await _loadUnreadCount();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
