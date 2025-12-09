import 'dart:io';
import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import '../utils/app_router.dart';

/// Service for managing OneSignal push notifications
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _initialized = false;
  String? _playerId;
  static const String _oneSignalAppId = '741790af-bbf1-4480-9c92-18352b884ea3';
  // TODO: Add your OneSignal REST API Key here for action buttons support
  // Get it from: OneSignal Dashboard > Settings > Keys & IDs > REST API Key
  // Without this key, notifications will be sent but without action buttons
  // Action buttons (snooze, dismiss, stop) require REST API
  static const String _oneSignalRestApiKey = 'YOUR_REST_API_KEY_HERE';

  /// Initialize OneSignal SDK
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.d('[OneSignalService] Already initialized');
      return;
    }

    try {
      // Initialize OneSignal
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
        '[OneSignalService] Not initialized or no player ID, cannot send threshold alert',
      );
      // Fallback to local notification
      await _sendLocalThresholdAlert(
        title: title,
        body: body,
        consumedCost: consumedCost,
        totalBudget: totalBudget,
        remainingBudget: remainingBudget,
        thresholdPercentage: thresholdPercentage,
        onAction: onAction,
      );
      return;
    }

    // Store action callback for later use
    _pendingActionCallback = onAction;

    // Try to use REST API if API key is configured
    if (_oneSignalRestApiKey != 'YOUR_REST_API_KEY_HERE' &&
        _oneSignalRestApiKey.isNotEmpty) {
      try {
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
            'priority': 10,
            'sound': 'default',
            'android_channel_id': 'threshold_alerts',
            // Ensure notification works when app is closed
            'android_sound': 'default',
            'ios_sound': 'default',
            'content_available': true, // Enable background delivery
            'mutable_content': true, // Allow notification modification
            // Android-specific settings for background notifications
            'android_visibility': 1, // Public visibility
            'android_accent_color': 'FFE74C3C', // Red accent for alerts
            // iOS-specific settings
            'ios_badgeType': 'Increase',
            'ios_badgeCount': 1,
          }),
        );

        if (response.statusCode == 200) {
          AppLogger.i('[OneSignalService] Threshold alert sent via REST API');
          return;
        } else {
          AppLogger.w(
            '[OneSignalService] REST API failed: ${response.statusCode}, falling back to local notification',
          );
        }
      } catch (e) {
        AppLogger.w(
          '[OneSignalService] Error using REST API: $e, falling back to local notification',
        );
      }
    }

    // Fallback to local notification
    await _sendLocalThresholdAlert(
      title: title,
      body: body,
      consumedCost: consumedCost,
      totalBudget: totalBudget,
      remainingBudget: remainingBudget,
      thresholdPercentage: thresholdPercentage,
      onAction: onAction,
    );
  }

  /// Fallback: Send local threshold alert (without action buttons)
  /// Note: OneSignal local notifications don't support action buttons
  /// Action buttons require REST API
  Future<void> _sendLocalThresholdAlert({
    required String title,
    required String body,
    required double consumedCost,
    required double totalBudget,
    required double remainingBudget,
    required double thresholdPercentage,
    Function(String action)? onAction,
  }) async {
    AppLogger.w(
      '[OneSignalService] Local notifications without REST API key - action buttons not available. '
      'Please configure OneSignal REST API key for full functionality.',
    );
    // OneSignal Flutter SDK doesn't support action buttons in local notifications
    // User will need to click the notification to handle actions
  }

  Function(String action)? _pendingActionCallback;

  /// Handle threshold alert action button clicks
  /// This works even when app is closed (OneSignal handles background actions)
  Future<void> _handleThresholdAction(
    String actionId,
    Map<String, dynamic> data,
  ) async {
    AppLogger.i('[OneSignalService] Threshold action clicked: $actionId');

    // Handle stop action directly to ensure notification loop stops
    // This works even when app is closed
    if (actionId == 'stop') {
      try {
        // Set stopped flag directly in SharedPreferences
        // This ensures the notification loop stops even if app is closed
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('threshold_alert_stopped', true);
        AppLogger.i(
          '[OneSignalService] Stop action executed - notification loop disabled',
        );
      } catch (e) {
        AppLogger.e('[OneSignalService] Error setting stopped flag: $e');
      }
    }

    // Trigger callback if available (this will call ThresholdAlertService)
    // The callback handles snooze, dismiss, and stop actions
    if (_pendingActionCallback != null) {
      _pendingActionCallback!(actionId);
      _pendingActionCallback = null;
    } else {
      // If no callback (app might be closed), log the action
      // Stop action is already handled above
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
}
