import 'dart:io';
import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import '../utils/app_router.dart';
import 'threshold_alert_service.dart';

/// Service for managing OneSignal push notifications
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _initialized = false;
  String? _playerId;
  static const String _oneSignalAppId = '741790af-bbf1-4480-9c92-18352b884ea3';
  // OneSignal REST API Key for action buttons support
  // Action buttons (snooze, dismiss, stop) require REST API
  static const String _oneSignalRestApiKey =
      'os_v2_app_oqlzbl536fcibhesda2sxccouom43csqdcaulf4m3xigbvnnujd5lckbdgwz74v4jafijp2muzpjx6y5mkvvbo6nnac7cfcazacz6va';

  /// Initialize OneSignal SDK
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.d('[OneSignalService] Already initialized');
      return;
    }

    try {
      // Initialize OneSignal with settings optimized for background delivery
      OneSignal.initialize(_oneSignalAppId);

      // Request notification permissions
      final permissionResult = await OneSignal.Notifications.requestPermission(
        true,
      );
      AppLogger.i(
        '[OneSignalService] Notification permission: ${permissionResult}',
      );

      // Get initial player ID and store in Firestore
      final subscription = OneSignal.User.pushSubscription;
      _playerId = subscription.id;

      if (_playerId != null && _playerId!.isNotEmpty) {
        await _storePlayerId(_playerId!);
        AppLogger.i('[OneSignalService] Initial Player ID stored: $_playerId');
      } else {
        AppLogger.w('[OneSignalService] Player ID is null or empty');
      }

      // Listen for player ID changes (e.g., when user reinstalls app)
      OneSignal.User.pushSubscription.addObserver((state) async {
        final newPlayerId = state.current.id;
        if (newPlayerId != null &&
            newPlayerId.isNotEmpty &&
            newPlayerId != _playerId) {
          AppLogger.i(
            '[OneSignalService] Player ID changed: $_playerId -> $newPlayerId',
          );
          _playerId = newPlayerId;
          await _storePlayerId(newPlayerId);
        }
      });

      // Handle notification clicked/opened (works even when app is closed)
      OneSignal.Notifications.addClickListener((event) async {
        AppLogger.i(
          '[OneSignalService] Notification clicked: ${event.notification.notificationId}',
        );

        final additionalData = event.notification.additionalData;
        if (additionalData != null) {
          final type = additionalData['type'] as String?;

          // Check if this is an action button click
          // OneSignal REST API action buttons pass the action ID in additionalData
          // The button ID from the REST API 'buttons' array is passed as 'actionSelected'
          String? actionId;
          try {
            // For REST API notifications with buttons, the action ID is in additionalData
            // Try common field names used by OneSignal
            actionId = additionalData['actionSelected'] as String?;
            if (actionId == null) {
              actionId = additionalData['actionId'] as String?;
            }
            if (actionId == null) {
              actionId = additionalData['action'] as String?;
            }
            // Also check event.result if available (for newer SDK versions)
            if (actionId == null) {
              try {
                // Try to access actionId from result object
                final result = event.result;
                final resultMap = result as Map<String, dynamic>?;
                if (resultMap != null) {
                  actionId = resultMap['actionId'] as String?;
                }
              } catch (e) {
                AppLogger.d(
                  '[OneSignalService] Could not read actionId from result: $e',
                );
              }
            }
            AppLogger.d('[OneSignalService] Action ID detected: $actionId');
          } catch (e) {
            AppLogger.d('[OneSignalService] No action ID in click event: $e');
          }

          if (actionId != null &&
              actionId.isNotEmpty &&
              type == 'threshold_alert') {
            await _handleThresholdAction(actionId, additionalData);
            return;
          }

          if (type == 'threshold_alert' ||
              type == 'threshold_reached' ||
              type == 'budget_alert') {
            // If no action button was clicked, navigate to Goals page
            appRouter.go('/home?tab=2');
            AppLogger.i(
              '[OneSignalService] Navigated to Goals page from notification',
            );
          } else {
            // Handle other notification types
            _handleNotificationClick(type, additionalData);
          }
        }
      });

      _initialized = true;
      AppLogger.i('[OneSignalService] OneSignal initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.e('[OneSignalService] Error initializing OneSignal: $e');
      AppLogger.e('[OneSignalService] Stack trace: $stackTrace');
      // Don't rethrow - allow app to continue without OneSignal
    }
  }

  /// Store player ID in Firestore
  Future<void> _storePlayerId(String playerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppLogger.w(
        '[OneSignalService] No authenticated user, cannot store player ID',
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('oneSignalPlayerIds')
          .doc(playerId)
          .set({
            'playerId': playerId,
            'platform': _getPlatform(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      AppLogger.i(
        '[OneSignalService] Player ID stored in Firestore: $playerId',
      );
    } catch (e) {
      AppLogger.e(
        '[OneSignalService] Error storing player ID in Firestore: $e',
      );
    }
  }

  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Get current player ID
  String? get playerId => _playerId;

  /// Check if OneSignal is initialized
  bool get isInitialized => _initialized;

  /// Whether REST API key is present (required for action buttons)
  bool get hasRestApiKeyConfigured =>
      _oneSignalRestApiKey != 'YOUR_REST_API_KEY_HERE' &&
      _oneSignalRestApiKey.isNotEmpty;

  /// Send tags to OneSignal (for user segmentation)
  Future<void> setTags(Map<String, String> tags) async {
    if (!_initialized) {
      AppLogger.w('[OneSignalService] Not initialized, cannot set tags');
      return;
    }

    try {
      await OneSignal.User.addTags(tags);
      AppLogger.i('[OneSignalService] Tags set: $tags');
    } catch (e) {
      AppLogger.e('[OneSignalService] Error setting tags: $e');
    }
  }

  /// Remove tags from OneSignal
  Future<void> removeTags(List<String> keys) async {
    if (!_initialized) {
      AppLogger.w('[OneSignalService] Not initialized, cannot remove tags');
      return;
    }

    try {
      await OneSignal.User.removeTags(keys);
      AppLogger.i('[OneSignalService] Tags removed: $keys');
    } catch (e) {
      AppLogger.e('[OneSignalService] Error removing tags: $e');
    }
  }

  /// Send threshold alert notification with action buttons (snooze, dismiss, stop)
  /// Uses OneSignal REST API to support action buttons
  /// Works even when app is closed (background delivery via OneSignal)
  Future<void> sendThresholdAlert({
    required String title,
    required String body,
    required double consumedCost,
    required double totalBudget,
    required double remainingBudget,
    required double thresholdPercentage,
    Function(String action)? onAction,
  }) async {
    if (!_initialized || _playerId == null || _playerId!.isEmpty) {
      AppLogger.w(
        '[OneSignalService] Not initialized or no player ID, cannot send threshold alert. '
        'Please ensure OneSignal is properly initialized.',
      );
      return;
    }

    // Store action callback for later use
    _pendingActionCallback = onAction;

    // Try to use REST API if API key is configured
    if (_oneSignalRestApiKey != 'YOUR_REST_API_KEY_HERE' &&
        _oneSignalRestApiKey.isNotEmpty) {
      try {
        // OneSignal REST API expects REST API key in Authorization header
        // Format: "Basic {REST_API_KEY}" (the key itself, not base64 encoded)
        final response = await http.post(
          Uri.parse('https://onesignal.com/api/v1/notifications'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Basic $_oneSignalRestApiKey',
          },
          body: jsonEncode({
            'app_id': _oneSignalAppId,
            'include_player_ids': [_playerId],
            'headings': {'en': title},
            'contents': {'en': body},
            'data': {
              'type': 'threshold_alert',
              'consumedCost': consumedCost.toStringAsFixed(2),
              'totalBudget': totalBudget.toStringAsFixed(2),
              'remainingBudget': remainingBudget.toStringAsFixed(2),
              'thresholdPercentage': thresholdPercentage.toStringAsFixed(1),
            },
            'buttons': [
              {'id': 'snooze', 'text': 'Snooze'},
              {'id': 'dismiss', 'text': 'Dismiss'},
              {'id': 'stop', 'text': 'Stop'},
            ],
            // High priority ensures notification is delivered even when app is closed
            'priority': 10,
            'ttl':
                86400, // Time to live: 24 hours (ensures notification isn't lost)
            'sound': 'default',
            'android_channel_id': 'threshold_alerts',
            // Ensure notification works when app is closed
            'android_sound': 'default',
            'ios_sound': 'default',
            'content_available': true, // Enable background delivery (iOS)
            'mutable_content': true, // Allow notification modification
            // Android-specific settings for background notifications
            'android_visibility': 1, // Public visibility (show on lock screen)
            'android_accent_color': 'FFE74C3C', // Red accent for alerts
            'android_priority':
                2, // High priority (2 = high, ensures delivery when app closed)
            'android_led_color': 'FFE74C3C', // LED color for notifications
            'android_small_icon': 'ic_notification', // Small icon resource name
            'android_large_icon': 'ic_notification', // Large icon resource name
            // Ensure notification wakes device and shows on lock screen
            'android_badge_icon_type': 'LargeIcon',
            // iOS-specific settings
            'ios_badgeType': 'Increase',
            'ios_badgeCount': 1,
            // Additional settings to ensure delivery
            'send_after': null, // Send immediately
            'delayed_option': null, // No delay
          }),
        );

        if (response.statusCode == 200) {
          AppLogger.i(
            '[OneSignalService] ✅ Threshold alert sent via REST API (works when app is closed)',
          );
          return;
        } else {
          AppLogger.e(
            '[OneSignalService] ❌ REST API failed: ${response.statusCode} - ${response.body}',
          );
          // Log error but don't throw - allow system to continue
          // The notification won't be sent, but the app won't crash
        }
      } catch (e) {
        AppLogger.e('[OneSignalService] ❌ Error using REST API: $e');
        // Log error but don't throw - allow system to continue
      }
    } else {
      // REST API key not configured - cannot send notifications with action buttons
      AppLogger.e(
        '[OneSignalService] ❌ REST API key not configured. '
        'Cannot send notifications with action buttons. '
        'Please configure OneSignal REST API key in onesignal_service.dart',
      );
      // Don't throw - just log the error
      // The notification won't be sent, but the app won't crash
    }
  }

  Function(String action)? _pendingActionCallback;

  /// Handle threshold alert action button clicks
  /// This works even when app is closed (OneSignal handles background actions)
  Future<void> _handleThresholdAction(
    String actionId,
    Map<String, dynamic> data,
  ) async {
    AppLogger.i('[OneSignalService] Threshold action clicked: $actionId');

    // Handle stop and dismiss actions directly to ensure notification loop updates
    // This works even when app is closed
    if (actionId == 'stop') {
      try {
        // Persist stop state so background loop halts everywhere (permanent)
        await ThresholdAlertService.instance.markStoppedFromRemote();
        AppLogger.i(
          '[OneSignalService] Stop action persisted - notifications permanently disabled',
        );
      } catch (e) {
        AppLogger.e('[OneSignalService] Error setting stopped flag: $e');
      }
    } else if (actionId == 'dismiss') {
      try {
        // Persist dismiss state so background loop pauses temporarily
        // Notifications will auto-resume when threshold is reached again
        await ThresholdAlertService.instance.markDismissedFromRemote();
        AppLogger.i(
          '[OneSignalService] Dismiss action persisted - notifications temporarily paused (will auto-resume)',
        );
      } catch (e) {
        AppLogger.e('[OneSignalService] Error setting dismissed flag: $e');
      }
    }

    // Trigger callback if available (this will call ThresholdAlertService)
    // The callback handles snooze, dismiss, and stop actions
    if (_pendingActionCallback != null) {
      _pendingActionCallback!(actionId);
      _pendingActionCallback = null;
    } else {
      // If no callback (app might be closed), actions are already handled above
      AppLogger.d(
        '[OneSignalService] Action handled without callback (app may be closed): $actionId',
      );
    }
  }

  /// Cancel threshold alert notification
  Future<void> cancelThresholdAlert() async {
    if (!_initialized) return;

    try {
      // OneSignal doesn't have a direct method to cancel notifications
      // Notifications are typically cancelled server-side or expire naturally
      _pendingActionCallback = null;
      AppLogger.i('[OneSignalService] Threshold alert callback cleared');
    } catch (e) {
      AppLogger.e('[OneSignalService] Error cancelling threshold alert: $e');
    }
  }

  /// Check if notification was already sent (prevents duplicates)
  Future<bool> _wasNotificationSent(String notificationKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(notificationKey) ?? false;
    } catch (e) {
      AppLogger.e('[OneSignalService] Error checking notification sent: $e');
      return false;
    }
  }

  /// Mark notification as sent in SharedPreferences
  Future<void> _markNotificationSent(String notificationKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(notificationKey, true);
      // Store timestamp for cleanup (optional - can clean old entries periodically)
      await prefs.setString(
        '${notificationKey}_timestamp',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      AppLogger.e('[OneSignalService] Error marking notification sent: $e');
    }
  }

  /// Clear notification sent flag (for testing or resending)
  Future<void> clearNotificationSent(String notificationKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(notificationKey);
      await prefs.remove('${notificationKey}_timestamp');
    } catch (e) {
      AppLogger.e('[OneSignalService] Error clearing notification sent: $e');
    }
  }

  /// Send generic notification via OneSignal REST API
  /// Uses SharedPreferences to prevent duplicate notifications
  Future<void> sendNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    String? notificationKey, // Unique key for duplicate prevention
    bool preventDuplicates = true,
  }) async {
    if (!_initialized || _playerId == null || _playerId!.isEmpty) {
      AppLogger.w(
        '[OneSignalService] Not initialized or no player ID, cannot send notification',
      );
      return;
    }

    // Check for duplicates if preventDuplicates is enabled
    if (preventDuplicates && notificationKey != null) {
      final wasSent = await _wasNotificationSent(notificationKey);
      if (wasSent) {
        AppLogger.d(
          '[OneSignalService] Notification already sent (key: $notificationKey), skipping duplicate',
        );
        return;
      }
    }

    // Try to use REST API if API key is configured
    if (_oneSignalRestApiKey != 'YOUR_REST_API_KEY_HERE' &&
        _oneSignalRestApiKey.isNotEmpty) {
      try {
        final notificationData = {'type': type, if (data != null) ...data};

        final response = await http.post(
          Uri.parse('https://onesignal.com/api/v1/notifications'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Basic $_oneSignalRestApiKey',
          },
          body: jsonEncode({
            'app_id': _oneSignalAppId,
            'include_player_ids': [_playerId],
            'headings': {'en': title},
            'contents': {'en': body},
            'data': notificationData,
            'priority': 10,
            'ttl': 86400, // 24 hours
            'sound': 'default',
            'android_sound': 'default',
            'ios_sound': 'default',
            'content_available': true,
            'mutable_content': true,
            'android_visibility': 1,
            'android_priority': 2,
          }),
        );

        if (response.statusCode == 200) {
          AppLogger.i(
            '[OneSignalService] Notification sent via REST API: $type',
          );

          // Mark as sent to prevent duplicates
          if (preventDuplicates && notificationKey != null) {
            await _markNotificationSent(notificationKey);
          }
          return;
        } else {
          AppLogger.w(
            '[OneSignalService] REST API failed: ${response.statusCode}',
          );
        }
      } catch (e) {
        AppLogger.w('[OneSignalService] Error using REST API: $e');
      }
    } else {
      AppLogger.w(
        '[OneSignalService] REST API key not configured, cannot send notification',
      );
    }
  }

  /// Send chat message notification
  Future<void> sendChatNotification({
    required String senderName,
    required String messagePreview,
    required String chatId,
    String? messageId,
  }) async {
    final notificationKey =
        'chat_${chatId}_${messageId ?? DateTime.now().millisecondsSinceEpoch}';

    await sendNotification(
      title: senderName,
      body: messagePreview,
      type: 'chat_message',
      notificationKey: notificationKey,
      data: {'chatId': chatId, if (messageId != null) 'messageId': messageId},
    );
  }

  /// Send rate update notification
  Future<void> sendRateUpdateNotification({
    required double oldRate,
    required double newRate,
  }) async {
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

    final notificationKey = 'rate_update_${newRate.toStringAsFixed(4)}';

    await sendNotification(
      title: '$changeIcon Power Rate Updated',
      body:
          'Rate $changeText from ₱${oldRate.toStringAsFixed(4)}/kWh to ₱${newRate.toStringAsFixed(4)}/kWh',
      type: 'rate_update',
      notificationKey: notificationKey,
      data: {'oldRate': oldRate.toString(), 'newRate': newRate.toString()},
    );
  }

  /// Send appliance status notification
  Future<void> sendApplianceStatusNotification({
    required String applianceName,
    required bool isOn,
    required double? cost,
  }) async {
    final status = isOn ? 'turned ON' : 'turned OFF';
    final costText = cost != null ? ' (₱${cost.toStringAsFixed(2)})' : '';
    final notificationKey =
        'appliance_${applianceName}_${isOn ? 'on' : 'off'}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}'; // Per minute

    await sendNotification(
      title: 'Appliance $status',
      body: '$applianceName has been $status$costText',
      type: 'appliance_status',
      notificationKey: notificationKey,
      data: {
        'applianceName': applianceName,
        'isOn': isOn.toString(),
        if (cost != null) 'cost': cost.toString(),
      },
      preventDuplicates: true,
    );
  }

  /// Send goal achievement notification
  Future<void> sendGoalAchievementNotification({
    required String achievementType,
    required String message,
  }) async {
    final notificationKey =
        'goal_achievement_${achievementType}_${DateTime.now().toIso8601String().split('T')[0]}'; // Per day

    await sendNotification(
      title: 'Goal Achieved! 🎉',
      body: message,
      type: 'goal_achievement',
      notificationKey: notificationKey,
      data: {'achievementType': achievementType},
    );
  }

  /// Send daily summary notification
  Future<void> sendDailySummaryNotification({
    required double totalCost,
    required double totalKwh,
    required double targetCost,
    required double targetKwh,
  }) async {
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

    final notificationKey =
        'daily_summary_${DateTime.now().toIso8601String().split('T')[0]}'; // Per day

    await sendNotification(
      title: 'Daily Energy Summary',
      body: message,
      type: 'daily_summary',
      notificationKey: notificationKey,
      data: {
        'totalCost': totalCost.toString(),
        'totalKwh': totalKwh.toString(),
        'targetCost': targetCost.toString(),
        'targetKwh': targetKwh.toString(),
      },
    );
  }

  /// Handle notification click for different types
  void _handleNotificationClick(String? type, Map<String, dynamic>? data) {
    if (type == null) return;

    switch (type) {
      case 'chat_message':
        final chatId = data?['chatId'] as String?;
        if (chatId != null) {
          appRouter.go('/supportChat');
        }
        break;
      case 'rate_update':
        // Navigate to settings or home
        appRouter.go('/home');
        break;
      case 'appliance_status':
        // Navigate to monitoring
        appRouter.go('/home?tab=1');
        break;
      case 'goal_achievement':
        // Navigate to goals
        appRouter.go('/home?tab=2');
        break;
      case 'daily_summary':
        // Navigate to home
        appRouter.go('/home');
        break;
      default:
        AppLogger.d('[OneSignalService] Unknown notification type: $type');
    }
  }
}
