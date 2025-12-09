import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import 'threshold_alert_service.dart';
import 'onesignal_service.dart';

/// Service for managing notifications via OneSignal.
/// All local notifications are replaced with OneSignal push notifications.
class NotificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isInitialized = false;

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Initialize notification service (OneSignal is initialized separately).
  Future<void> initialize({bool requestPermission = true}) async {
    if (_isInitialized) return;

    try {
      // Ensure OneSignal is initialized
      if (!OneSignalService.instance.isInitialized) {
        await OneSignalService.instance.initialize();
      }

      _isInitialized = true;
      AppLogger.i(
        '[NotificationService] Notification service initialized with OneSignal',
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error initializing notifications: $e');
    }
  }

  Future<void> ensureInitializedForBackground() async {
    if (!_isInitialized) {
      await initialize(requestPermission: false);
    }
  }

  /// Request notification permissions (delegated to OneSignal).
  Future<void> requestPermissions() async {
    try {
      if (!OneSignalService.instance.isInitialized) {
        await OneSignalService.instance.initialize();
      }
      AppLogger.i('[NotificationService] Notification permission requested');
    } catch (e) {
      AppLogger.e('[NotificationService] Error requesting permissions: $e');
    }
  }

  /// Check if user has chosen "Proceed" for current budget alert
  Future<bool> isProceedActive() async {
    return ThresholdAlertService.instance.isAlertActive();
  }

  /// Reset proceed state (call when new budget alert is created)
  Future<void> resetProceedState() async {
    await ThresholdAlertService.instance.resetState();
  }

  /// Send critical alert via OneSignal.
  Future<void> sendCriticalAlert({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await OneSignalService.instance.sendNotification(
        title: title,
        body: body,
        type: 'critical_alert',
        data: data,
        notificationKey: 'critical_${DateTime.now().millisecondsSinceEpoch}',
        preventDuplicates: false, // Critical alerts should always be sent
      );
      AppLogger.i('[NotificationService] Critical alert sent: $title');
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending critical alert: $e');
    }
  }

  /// Send local notification for non-critical alerts (via OneSignal).
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await OneSignalService.instance.sendNotification(
        title: title,
        body: body,
        type: 'status',
        data: payload,
        notificationKey: 'status_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending local notification: $e');
    }
  }

  /// Send appliance status notification via OneSignal.
  Future<void> sendApplianceStatusNotification({
    required String applianceName,
    required bool isOn,
    required double? cost,
  }) async {
    try {
      await OneSignalService.instance.sendApplianceStatusNotification(
        applianceName: applianceName,
        isOn: isOn,
        cost: cost,
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending appliance status: $e');
    }
  }

  /// Show chat message notification via OneSignal.
  Future<void> showChatMessageNotification({
    required String senderName,
    required String messagePreview,
    required String chatId,
    String? messageId,
  }) async {
    try {
      await OneSignalService.instance.sendChatNotification(
        senderName: senderName,
        messagePreview: messagePreview,
        chatId: chatId,
        messageId: messageId,
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error showing chat notification: $e');
    }
  }

  /// Show power rate update notification via OneSignal.
  Future<void> showRateUpdateNotification({
    required double oldRate,
    required double newRate,
  }) async {
    try {
      await OneSignalService.instance.sendRateUpdateNotification(
        oldRate: oldRate,
        newRate: newRate,
      );
      AppLogger.i(
        '[NotificationService] Rate update notification shown: ₱$oldRate → ₱$newRate',
      );
    } catch (e) {
      AppLogger.e(
        '[NotificationService] Error showing rate update notification: $e',
      );
    }
  }

  /// Send goal achievement notification via OneSignal.
  Future<void> sendGoalAchievementNotification({
    required String achievementType,
    required String message,
  }) async {
    try {
      await OneSignalService.instance.sendGoalAchievementNotification(
        achievementType: achievementType,
        message: message,
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending goal achievement: $e');
    }
  }

  /// Send daily summary notification via OneSignal.
  Future<void> sendDailySummaryNotification({
    required double totalCost,
    required double totalKwh,
    required double targetCost,
    required double targetKwh,
  }) async {
    try {
      await OneSignalService.instance.sendDailySummaryNotification(
        totalCost: totalCost,
        totalKwh: totalKwh,
        targetCost: targetCost,
        targetKwh: targetKwh,
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending daily summary: $e');
    }
  }

  /// Send threshold reached notification.
  /// Note: Critical alerts should be sent via Cloud Functions
  /// This is kept for backward compatibility but logs a warning
  Future<void> sendThresholdReachedNotification({
    required String type,
    required double currentValue,
    required double thresholdValue,
    required double targetValue,
  }) async {
    try {
      AppLogger.w(
        '[NotificationService] Threshold notification should be sent via backend service.',
      );
    } catch (e) {
      AppLogger.e(
        '[NotificationService] Error sending threshold notification: $e',
      );
    }
  }

  /// Send budget threshold notification with persistent alert via OneSignal.
  Future<void> sendBudgetThresholdNotification({
    required double consumedCost,
    required double remainingBudget,
    required double totalBudget,
    required double thresholdPercentage,
    bool bypassDailyCheck = false,
    String alertType = 'threshold',
    String budgetId = 'current',
    String? budgetName,
  }) async {
    try {
      // Check if alerts are stopped before sending
      final isStopped = await ThresholdAlertService.instance.isAlertsStopped();
      if (isStopped && !bypassDailyCheck) {
        AppLogger.i(
          '[NotificationService] Alerts are stopped - skipping threshold notification',
        );
        return;
      }

      await ThresholdAlertService.instance.triggerAlert(
        consumedCost: consumedCost,
        totalBudget: totalBudget,
        remainingBudget: remainingBudget,
        thresholdPercentage: thresholdPercentage,
        force: bypassDailyCheck,
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending threshold alert: $e');
    }
  }

  /// Schedule periodic notifications (not supported via OneSignal REST API).
  /// For scheduled notifications, use Cloud Functions or backend services.
  Future<void> schedulePeriodicNotifications() async {
    try {
      AppLogger.w(
        '[NotificationService] Scheduled notifications should be handled via backend services or Cloud Functions.',
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error scheduling notifications: $e');
    }
  }

  /// Cancel all notifications (not directly supported by OneSignal).
  /// Notifications are typically cancelled server-side or expire naturally.
  Future<void> cancelAllNotifications() async {
    try {
      AppLogger.d(
        '[NotificationService] OneSignal notifications cannot be cancelled directly. '
        'They expire naturally or are cancelled server-side.',
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error canceling notifications: $e');
    }
  }

  /// Cancel specific notification (not directly supported by OneSignal).
  Future<void> cancelNotification(int id) async {
    try {
      AppLogger.d(
        '[NotificationService] OneSignal notifications cannot be cancelled directly. '
        'They expire naturally or are cancelled server-side.',
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error canceling notification: $e');
    }
  }

  /// Get notification history from Firestore.
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'sent': data['sent'] ?? false,
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      AppLogger.e(
        '[NotificationService] Error getting notification history: $e',
      );
      return [];
    }
  }

  /// Test notification via OneSignal.
  Future<void> sendTestNotification() async {
    try {
      await OneSignalService.instance.sendNotification(
        title: 'Test Notification',
        body: 'This is a test notification from Energy Smart',
        type: 'test',
        notificationKey: 'test_${DateTime.now().millisecondsSinceEpoch}',
        preventDuplicates: false,
      );
      AppLogger.i('[NotificationService] Test notification sent');
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending test notification: $e');
      rethrow;
    }
  }

  /// Check notification permissions (delegated to OneSignal).
  Future<bool> areNotificationsEnabled() async {
    try {
      return OneSignalService.instance.isInitialized;
    } catch (e) {
      AppLogger.e('[NotificationService] Error checking permissions: $e');
      return false;
    }
  }

  /// Open notification settings (delegated to OneSignal).
  Future<void> openNotificationSettings() async {
    try {
      if (!OneSignalService.instance.isInitialized) {
        await OneSignalService.instance.initialize();
      }
    } catch (e) {
      AppLogger.e('[NotificationService] Error opening settings: $e');
    }
  }

  /// Enable threshold notifications.
  Future<void> enableThresholdNotifications() async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('notifications')
          .set({
            'thresholdNotifications': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.e(
        '[NotificationService] Error enabling threshold notifications: $e',
      );
      rethrow;
    }
  }

  /// Disable threshold notifications.
  Future<void> disableThresholdNotifications() async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('notifications')
          .set({
            'thresholdNotifications': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.e(
        '[NotificationService] Error disabling threshold notifications: $e',
      );
      rethrow;
    }
  }

  /// Legacy method name for backward compatibility.
  @Deprecated('Use initialize instead')
  Future<void> configureAwesomeNotifications() async {
    await initialize();
  }
}
