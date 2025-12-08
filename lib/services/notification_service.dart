import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import '../utils/app_router.dart';
import 'threshold_alert_service.dart';

/// Service for managing local notifications.
class NotificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isInitialized = false;

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Initialize local notification channels.
  Future<void> initialize({bool requestPermission = true}) async {
    if (_isInitialized) return;

    try {
      if (requestPermission) {
        await requestPermissions();
      }

      // Initialize Awesome Notifications for local non-critical alerts
      await _initializeLocalNotifications();

      // Set up AwesomeNotifications action listeners
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: _onNotificationActionReceived,
        onNotificationCreatedMethod: _onNotificationCreated,
        onNotificationDisplayedMethod: _onNotificationDisplayed,
        onDismissActionReceivedMethod: _onNotificationDismissed,
      );

      _isInitialized = true;
      AppLogger.i('[NotificationService] Local notifications initialized');
    } catch (e) {
      AppLogger.e('[NotificationService] Error initializing notifications: $e');
    }
  }

  Future<void> ensureInitializedForBackground() async {
    if (!_isInitialized) {
      await initialize(requestPermission: false);
    }
  }

  /// Initialize Awesome Notifications for local non-critical alerts
  Future<void> _initializeLocalNotifications() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'appliance_status',
        channelName: 'Appliance Status',
        channelDescription: 'Notifications for appliance status changes',
        defaultColor: const Color(0xFFF39C12),
        ledColor: const Color(0xFFF39C12),
        playSound: false,
        enableVibration: false,
        importance: NotificationImportance.Low,
      ),
      NotificationChannel(
        channelKey: 'chat_messages',
        channelName: 'Chat Messages',
        channelDescription: 'Notifications for support chat conversations',
        defaultColor: const Color(0xFF3498DB),
        ledColor: const Color(0xFF3498DB),
        playSound: true,
        enableVibration: true,
        importance: NotificationImportance.High,
      ),
      NotificationChannel(
        channelKey: 'rate_updates',
        channelName: 'Power Rate Updates',
        channelDescription: 'Notifications when power rates are updated',
        defaultColor: const Color(0xFF27AE60),
        ledColor: const Color(0xFF27AE60),
        playSound: true,
        enableVibration: true,
        importance: NotificationImportance.High,
      ),
      NotificationChannel(
        channelKey: 'budget_alerts',
        channelName: 'Budget Alerts',
        channelDescription: 'Critical alerts for budget threshold reached',
        defaultColor: const Color(0xFFE74C3C),
        ledColor: const Color(0xFFE74C3C),
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1200, 400, 1200, 400, 1200]),
        importance: NotificationImportance.High,
        criticalAlerts: true,
      ),
      NotificationChannel(
        channelKey: 'threshold_alerts',
        channelName: 'Threshold Alerts',
        channelDescription: 'Persistent alerts when usage exceeds thresholds',
        defaultColor: const Color(0xFFE74C3C),
        ledColor: const Color(0xFFE74C3C),
        playSound: true,
        enableVibration: true,
        importance: NotificationImportance.Max,
        criticalAlerts: true,
        locked: true,
        vibrationPattern: Int64List.fromList([
          0,
          1800,
          600,
          1800,
          600,
          1800,
          600,
          1800,
          600,
          1800,
          600,
        ]),
        defaultRingtoneType: DefaultRingtoneType.Alarm,
        defaultPrivacy: NotificationPrivacy.Public,
      ),
    ], debug: true);

    await ThresholdAlertService.instance.ensureChannelReady();
  }

  /// Request notification permissions
  Future<void> requestPermissions() async {
    try {
      final localAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!localAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey: 'threshold_alerts',
        );
      }
      AppLogger.i('[NotificationService] Notification permission granted');
    } catch (e) {
      AppLogger.e('[NotificationService] Error requesting permissions: $e');
    }
  }

  /// Handle AwesomeNotifications action received (tap or button)
  @pragma('vm:entry-point')
  static Future<void> _onNotificationActionReceived(
    ReceivedAction receivedAction,
  ) async {
    try {
      final payload = receivedAction.payload;
      if (payload == null || payload.isEmpty) return;

      final type = payload['type'];
      final buttonKey = receivedAction.buttonKeyPressed;
      final alertId = payload['alertId'];

      // Allow threshold alert service to handle action buttons.
      await ThresholdAlertService.instance.handleAction(receivedAction);

      AppLogger.i(
        '[NotificationService] AwesomeNotification action received: type=$type, buttonKey=$buttonKey, alertId=$alertId',
      );

      // Handle budget alert actions
      if (type == 'budget_alert') {
        final buttonKey = receivedAction.buttonKeyPressed;
        // Get instance to call non-static methods
        final instance = NotificationService();

        // Handle action button clicks
        if (buttonKey == 'DISMISS') {
          AppLogger.i(
            '[NotificationService] Dismiss button clicked for budget alert',
          );
          // Dismiss notification and stop vibration
          // _handleDismissAction will cancel all budget alert notifications
          await instance._handleDismissAction(alertId);
          // Also dismiss this specific notification
          await AwesomeNotifications().dismiss(receivedAction.id!);
          return;
        } else if (buttonKey == 'PROCEED') {
          AppLogger.i(
            '[NotificationService] Proceed button clicked for budget alert',
          );
          // Proceed - continue notifications, don't dismiss
          await instance._handleProceedAction(alertId);
          // Keep notification active (don't dismiss)
          return;
        } else if (buttonKey == 'VIEW_GOALS' || buttonKey.isEmpty) {
          // View Goals button or notification body tapped
          AppLogger.i(
            '[NotificationService] Navigate to goals from local notification',
          );
          // Navigate to Goals page (tab index 2)
          appRouter.go('/home?tab=2');
          return;
        }
      }

      if (type == 'threshold_alert') {
        final button = receivedAction.buttonKeyPressed;
        if (button.isEmpty) {
          AppLogger.i(
            '[NotificationService] Threshold alert tapped - navigating to goals tab.',
          );
          appRouter.go('/home?tab=2');
        }
        return;
      }

      if (type == 'chat_message') {
        AppLogger.i(
          '[NotificationService] Chat notification tapped - navigating to support chat.',
        );
        appRouter.go('/supportChat');
        return;
      }
    } catch (e) {
      AppLogger.e(
        '[NotificationService] Error handling AwesomeNotification action: $e',
      );
    }
  }

  /// Handle AwesomeNotifications notification created
  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreated(
    ReceivedNotification receivedNotification,
  ) async {
    AppLogger.d(
      '[NotificationService] Notification created: ${receivedNotification.id}',
    );
  }

  /// Handle AwesomeNotifications notification displayed
  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayed(
    ReceivedNotification receivedNotification,
  ) async {
    AppLogger.d(
      '[NotificationService] Notification displayed: ${receivedNotification.id}',
    );
  }

  /// Handle AwesomeNotifications notification dismissed
  @pragma('vm:entry-point')
  static Future<void> _onNotificationDismissed(
    ReceivedAction receivedAction,
  ) async {
    AppLogger.d(
      '[NotificationService] Notification dismissed: ${receivedAction.id}',
    );
  }

  /// Handle "Proceed" action button click
  Future<void> _handleProceedAction(String? alertId) async {
    try {
      AppLogger.i(
        '[NotificationService] Proceed action clicked for alert: $alertId',
      );
      await ThresholdAlertService.instance.resetState();
    } catch (e) {
      AppLogger.e('[NotificationService] Error handling proceed action: $e');
    }
  }

  /// Handle "Dismiss" action button click
  Future<void> _handleDismissAction(String? alertId) async {
    try {
      AppLogger.i(
        '[NotificationService] Dismiss action clicked for alert: $alertId',
      );

      await ThresholdAlertService.instance.stopAlert();
    } catch (e) {
      AppLogger.e('[NotificationService] Error handling dismiss action: $e');
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

  /// Send critical alert (remote push notification placeholder).
  /// Note: Critical remote alerts are dispatched by backend services.
  Future<void> sendCriticalAlert({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // This method is for local testing only.
      AppLogger.i('[NotificationService] Critical alert would be sent: $title');
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending critical alert: $e');
    }
  }

  /// Send local notification for non-critical alerts
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'appliance_status',
          title: title,
          body: body,
          payload: payload?.map((k, v) => MapEntry(k, v.toString())),
          category: NotificationCategory.Status,
          largeIcon: 'resource://drawable/app_logo_wbg',
        ),
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending local notification: $e');
    }
  }

  /// Send appliance status notification (local - non-critical)
  Future<void> sendApplianceStatusNotification({
    required String applianceName,
    required bool isOn,
    required double? cost,
  }) async {
    try {
      final status = isOn ? 'turned ON' : 'turned OFF';
      final costText = cost != null ? ' (₱${cost.toStringAsFixed(2)})' : '';

      await sendLocalNotification(
        title: 'Appliance $status',
        body: '$applianceName has been $status$costText',
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending appliance status: $e');
    }
  }

  /// Show chat message notification (local - indicator style).
  Future<void> showChatMessageNotification({
    required String senderName,
    required String messagePreview,
    required String chatId,
    String? messageId,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'chat_messages',
          title: senderName,
          body: messagePreview,
          category: NotificationCategory.Message,
          payload: {
            'type': 'chat_message',
            'chatId': chatId,
            if (messageId != null) 'messageId': messageId,
          },
          largeIcon: 'resource://drawable/app_logo_wbg',
        ),
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error showing chat notification: $e');
    }
  }

  /// Show power rate update notification (local).
  Future<void> showRateUpdateNotification({
    required double oldRate,
    required double newRate,
  }) async {
    try {
      final rateChange = newRate - oldRate;
      final changeText =
          rateChange > 0
              ? 'increased'
              : rateChange < 0
              ? 'decreased'
              : 'updated';
      final changeIcon =
          rateChange > 0
              ? '📈'
              : rateChange < 0
              ? '📉'
              : '📊';

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'rate_updates',
          title: '$changeIcon Power Rate Updated',
          body:
              'Rate $changeText from ₱${oldRate.toStringAsFixed(4)}/kWh to ₱${newRate.toStringAsFixed(4)}/kWh',
          category: NotificationCategory.Status,
          payload: {
            'type': 'rate_update',
            'oldRate': oldRate.toString(),
            'newRate': newRate.toString(),
          },
          largeIcon: 'resource://drawable/app_logo_wbg',
        ),
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

  /// Send goal achievement notification (local - non-critical)
  Future<void> sendGoalAchievementNotification({
    required String achievementType,
    required String message,
  }) async {
    try {
      await sendLocalNotification(title: 'Goal Achieved! 🎉', body: message);
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending goal achievement: $e');
    }
  }

  /// Send daily summary notification (local - non-critical)
  Future<void> sendDailySummaryNotification({
    required double totalCost,
    required double totalKwh,
    required double targetCost,
    required double targetKwh,
  }) async {
    try {
      final costPercentage = (totalCost / targetCost * 100).toStringAsFixed(1);

      String message;
      if (totalCost <= targetCost * 0.8) {
        message =
            'Great job! You used ₱${totalCost.toStringAsFixed(2)} ($costPercentage% of target)';
      } else if (totalCost <= targetCost) {
        message =
            'Good progress! You used ₱${totalCost.toStringAsFixed(2)} ($costPercentage% of target)';
      } else {
        message =
            'You exceeded your target by ₱${(totalCost - targetCost).toStringAsFixed(2)}';
      }

      await sendLocalNotification(title: 'Daily Energy Summary', body: message);
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending daily summary: $e');
    }
  }

  /// Send threshold reached notification
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

  /// Send budget threshold notification with persistent local alert.
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
      await ThresholdAlertService.instance.triggerAlert(
        consumedCost: consumedCost,
        totalBudget: totalBudget,
        remainingBudget: remainingBudget,
        thresholdPercentage: thresholdPercentage,
        force: bypassDailyCheck,
      );
    } catch (e) {
      AppLogger.e(
        '[NotificationService] Error sending local threshold alert: $e',
      );
    }
  }

  /// Schedule periodic notifications (local)
  Future<void> schedulePeriodicNotifications() async {
    try {
      // Schedule daily summary at 9 PM
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1001,
          channelKey: 'appliance_status',
          title: 'Daily Energy Summary',
          body: 'Check your energy usage for today',
          category: NotificationCategory.Reminder,
          largeIcon: 'resource://drawable/app_logo_wbg',
        ),
        schedule: NotificationCalendar(
          hour: 21,
          minute: 0,
          second: 0,
          repeats: true,
        ),
      );
    } catch (e) {
      AppLogger.e('[NotificationService] Error scheduling notifications: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await AwesomeNotifications().cancelAll();
    } catch (e) {
      AppLogger.e('[NotificationService] Error canceling notifications: $e');
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await AwesomeNotifications().cancel(id);
    } catch (e) {
      AppLogger.e('[NotificationService] Error canceling notification: $e');
    }
  }

  /// Get notification history
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

  /// Test notification (local)
  Future<void> sendTestNotification() async {
    try {
      await sendLocalNotification(
        title: 'Test Notification',
        body: 'This is a test notification from Energy Smart',
      );
      AppLogger.i('[NotificationService] Test notification sent');
    } catch (e) {
      AppLogger.e('[NotificationService] Error sending test notification: $e');
      rethrow;
    }
  }

  /// Check notification permissions
  Future<bool> areNotificationsEnabled() async {
    try {
      return await AwesomeNotifications().isNotificationAllowed();
    } catch (e) {
      AppLogger.e('[NotificationService] Error checking permissions: $e');
      return false;
    }
  }

  /// Open notification settings
  Future<void> openNotificationSettings() async {
    try {
      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (!allowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    } catch (e) {
      AppLogger.e('[NotificationService] Error opening settings: $e');
    }
  }

  /// Enable threshold notifications
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

  /// Disable threshold notifications
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

  /// Legacy method name for backward compatibility
  @Deprecated('Use initialize instead')
  Future<void> configureAwesomeNotifications() async {
    await initialize();
  }
}
