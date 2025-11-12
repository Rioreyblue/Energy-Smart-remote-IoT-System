import 'package:awesome_notifications/awesome_notifications.dart';
import '../utils/app_logger.dart';

/// Service for handling chat notifications
class ChatNotificationService {
  static final ChatNotificationService _instance =
      ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  /// Initialize chat notification helpers (local only).
  Future<void> initialize() async {
    try {
      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (!allowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey: 'chat_messages',
        );
      }
      AppLogger.i('[ChatNotificationService] Chat notification helper ready');
    } catch (e) {
      AppLogger.e(
        '[ChatNotificationService] Error initializing chat notifications: $e',
      );
    }
  }
}
