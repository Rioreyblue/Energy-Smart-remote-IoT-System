import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '../utils/app_logger.dart';

/// Service for handling chat notifications
class ChatNotificationService {
  static final ChatNotificationService _instance =
      ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      // Request permission
      await _requestPermission();

      // Configure message handlers
      _configureMessageHandlers();

      // Get FCM token
      final token = await _messaging.getToken();
      AppLogger.i('[ChatNotificationService] 📱 [ChatNotificationService] FCM Token: $token');
    } catch (e) {
      AppLogger.e('[ChatNotificationService] ❌ [ChatNotificationService] Error initializing: $e');
    }
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      AppLogger.i('[ChatNotificationService] ✅ [ChatNotificationService] Notification permission granted');
    } else {
      AppLogger.i('[ChatNotificationService] ⚠️ [ChatNotificationService] Notification permission denied');
    }
  }

  /// Configure message handlers
  void _configureMessageHandlers() {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print(
      '📨 [ChatNotificationService] Foreground message: ${message.notification?.title}',
    );

    if (message.data['type'] == 'chat_message') {
      await _showChatNotification(message);
    }
  }

  /// Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print(
      '👆 [ChatNotificationService] Notification tapped: ${message.notification?.title}',
    );

    if (message.data['type'] == 'chat_message') {
      // Navigate to chat page
      // This would be handled by the main app
    }
  }

  /// Show chat notification
  Future<void> _showChatNotification(RemoteMessage message) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'chat_messages',
          title: message.notification?.title ?? 'New Message',
          body: message.notification?.body ?? 'You have a new message',
          payload: {
            'type': 'chat_message',
            'chatId': message.data['chatId'],
            'senderId': message.data['senderId'],
          },
        ),
      );
    } catch (e) {
      AppLogger.e('[ChatNotificationService] ❌ [ChatNotificationService] Error showing notification: $e');
    }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      AppLogger.e('[ChatNotificationService] ❌ [ChatNotificationService] Error getting token: $e');
      return null;
    }
  }

  /// Subscribe to chat topic
  Future<void> subscribeToChat(String userId) async {
    try {
      await _messaging.subscribeToTopic('chat_$userId');
      print(
        '✅ [ChatNotificationService] Subscribed to chat topic: chat_$userId',
      );
    } catch (e) {
      AppLogger.e('[ChatNotificationService] ❌ [ChatNotificationService] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from chat topic
  Future<void> unsubscribeFromChat(String userId) async {
    try {
      await _messaging.unsubscribeFromTopic('chat_$userId');
      print(
        '✅ [ChatNotificationService] Unsubscribed from chat topic: chat_$userId',
      );
    } catch (e) {
      AppLogger.e('[ChatNotificationService] ❌ [ChatNotificationService] Error unsubscribing from topic: $e');
    }
  }
}

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print(
    '📨 [ChatNotificationService] Background message: ${message.notification?.title}',
  );

  if (message.data['type'] == 'chat_message') {
    // Handle background chat message
    // You can save to local storage or show notification here
  }
}
