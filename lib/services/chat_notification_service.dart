import '../utils/app_logger.dart';
import 'onesignal_service.dart';

/// Service for handling chat notifications via OneSignal.
class ChatNotificationService {
  static final ChatNotificationService _instance =
      ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  /// Initialize chat notification helpers (OneSignal).
  Future<void> initialize() async {
    try {
      if (!OneSignalService.instance.isInitialized) {
        await OneSignalService.instance.initialize();
      }
      AppLogger.i('[ChatNotificationService] Chat notification helper ready');
    } catch (e) {
      AppLogger.e(
        '[ChatNotificationService] Error initializing chat notifications: $e',
      );
    }
  }
}
