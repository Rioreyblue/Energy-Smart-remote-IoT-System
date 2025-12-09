import 'dart:async';
import 'dart:typed_data';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import 'onesignal_service.dart';

/// Service responsible for presenting and managing persistent threshold alerts.
class ThresholdAlertService {
  ThresholdAlertService._();

  static final ThresholdAlertService instance = ThresholdAlertService._();
  static const MethodChannel _platformChannel = MethodChannel(
    'com.example.exercise_app/threshold_alert',
  );

  static const String _channelKey = 'threshold_alerts_v2';
  static const int _notificationId = 91001;

  static const String _prefsActiveKey = 'threshold_alert_active';
  static const String _prefsLastTriggerTs = 'threshold_alert_last_trigger_ts';
  static const String _prefsLastThresholdKey =
      'threshold_alert_last_threshold_value';
  static const String snoozePrefsKey = 'threshold_alert_snoozed_until';
  static const String _prefsStoppedKey =
      'threshold_alert_stopped'; // Flag to stop notification loop

  static const Duration _cooldown = Duration(minutes: 5);
  static const Duration _defaultSnoozeDuration = Duration(minutes: 5);

  bool _channelReady = false;

  /// Ensures that the threshold notification channel exists.
  Future<void> ensureChannelReady({bool fromBackground = false}) async {
    if (_channelReady) return;

    final channel = NotificationChannel(
      channelKey: _channelKey,
      channelName: 'Threshold Alerts',
      channelDescription: 'Alerts when energy or budget thresholds are reached',
      defaultColor: const Color(0xFFE74C3C),
      ledColor: const Color(0xFFE74C3C),
      importance: NotificationImportance.Max,
      locked: true,
      playSound: true,
      soundSource: 'resource://raw/alert_tone',
      enableVibration: true,
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
      criticalAlerts: true,
      channelShowBadge: true,
      defaultPrivacy: NotificationPrivacy.Public,
      defaultRingtoneType: DefaultRingtoneType.Alarm,
    );

    try {
      await AwesomeNotifications().setChannel(channel);
    } on PlatformException {
      await AwesomeNotifications().initialize(
        'resource://drawable/update_icon',
        [channel],
        debug: false,
      );
    } finally {
      _channelReady = true;
    }
  }

  /// Triggers an alert if cooldowns allow. Returns true if a new alert was shown.
  Future<bool> triggerAlert({
    required double consumedCost,
    required double totalBudget,
    required double remainingBudget,
    required double thresholdPercentage,
    bool force = false,
  }) async {
    await ensureChannelReady();

    final prefs = await SharedPreferences.getInstance();

    // Check if alerts were stopped by user
    final isStopped = prefs.getBool(_prefsStoppedKey) ?? false;
    if (isStopped && !force) {
      AppLogger.i(
        '[ThresholdAlertService] Alerts stopped by user - notification loop disabled.',
      );
      return false;
    }

    final now = DateTime.now();
    final lastTriggerRaw = prefs.getString(_prefsLastTriggerTs);
    final lastThreshold = prefs.getDouble(_prefsLastThresholdKey);
    DateTime? lastTrigger;
    if (lastTriggerRaw != null) {
      lastTrigger = DateTime.tryParse(lastTriggerRaw);
    }

    if (!force &&
        lastTrigger != null &&
        lastThreshold != null &&
        lastThreshold == thresholdPercentage &&
        now.difference(lastTrigger) < _cooldown) {
      AppLogger.d(
        '[ThresholdAlertService] Cooldown active. Skipping alert '
        '(last=${lastTrigger.toIso8601String()}, threshold=$lastThreshold)',
      );
      return false;
    }

    if (!await _canTriggerAfterSnooze()) {
      AppLogger.i('[ThresholdAlertService] Snooze active - skipping alert.');
      return false;
    }

    final usagePercent =
        totalBudget <= 0 ? 0 : (consumedCost / totalBudget * 100);

    await _startNativeAudio();
    await _clearSnooze();

    // Use OneSignal for threshold alerts with merged actions (snooze, dismiss, stop)
    if (OneSignalService.instance.isInitialized) {
      await OneSignalService.instance.sendThresholdAlert(
        title: '⚠️ Threshold Reached',
        body:
            'Usage ₱${consumedCost.toStringAsFixed(2)} of ₱${totalBudget.toStringAsFixed(2)} '
            '(${usagePercent.toStringAsFixed(1)}%). Remaining ₱${remainingBudget.toStringAsFixed(2)}.',
        consumedCost: consumedCost,
        totalBudget: totalBudget,
        remainingBudget: remainingBudget,
        thresholdPercentage: thresholdPercentage,
        onAction: (action) {
          // Handle action callback
          switch (action) {
            case 'snooze':
              _handleSnoozeAction();
              break;
            case 'dismiss':
              _handleDismissAction();
              break;
            case 'stop':
              _handleStopAction();
              break;
          }
        },
      );
    } else {
      // Fallback to AwesomeNotifications if OneSignal is not initialized
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _notificationId,
          channelKey: _channelKey,
          title: '⚠️ Threshold Reached',
          body:
              'Usage ₱${consumedCost.toStringAsFixed(2)} of ₱${totalBudget.toStringAsFixed(2)} '
              '(${usagePercent.toStringAsFixed(1)}%). Remaining ₱${remainingBudget.toStringAsFixed(2)}.',
          notificationLayout: NotificationLayout.BigText,
          autoDismissible: false,
          locked: true,
          wakeUpScreen: true,
          fullScreenIntent: true,
          criticalAlert: true,
          category: NotificationCategory.Alarm,
          customSound: 'resource://raw/alert_tone',
          displayOnForeground: true,
          displayOnBackground: true,
          icon: 'resource://drawable/update_icon',
          largeIcon: 'resource://drawable/update_icon',
          payload: {
            'type': 'threshold_alert',
            'threshold': thresholdPercentage.toStringAsFixed(1),
            'consumed': consumedCost.toStringAsFixed(2),
            'remaining': remainingBudget.toStringAsFixed(2),
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: _snoozeActionKey,
            label: 'Snooze',
            actionType: ActionType.SilentAction,
          ),
          NotificationActionButton(
            key: _dismissActionKey,
            label: 'Dismiss',
            actionType: ActionType.SilentAction,
            isDangerousOption: true,
          ),
          NotificationActionButton(
            key: _stopActionKey,
            label: 'Stop',
            actionType: ActionType.SilentAction,
            isDangerousOption: true,
          ),
        ],
      );
    }

    await prefs.setBool(_prefsActiveKey, true);
    await prefs.setString(_prefsLastTriggerTs, now.toIso8601String());
    await prefs.setDouble(_prefsLastThresholdKey, thresholdPercentage);

    AppLogger.i(
      '[ThresholdAlertService] Threshold alert displayed (threshold=$thresholdPercentage, consumed=$consumedCost)',
    );
    return true;
  }

  /// Cancels the active threshold alert notification.
  Future<void> stopAlert({bool clearCooldown = false}) async {
    await ensureChannelReady();

    // Cancel OneSignal notification if initialized
    if (OneSignalService.instance.isInitialized) {
      await OneSignalService.instance.cancelThresholdAlert();
    } else {
      // Fallback to AwesomeNotifications
      await AwesomeNotifications().cancel(_notificationId);
    }

    await _stopNativeAudio();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsActiveKey, false);
    if (clearCooldown) {
      await prefs.remove(_prefsLastTriggerTs);
      await prefs.remove(_prefsLastThresholdKey);
    }

    AppLogger.i('[ThresholdAlertService] Threshold alert stopped.');
  }

  /// Returns whether the persistent alert is currently marked as active.
  Future<bool> isAlertActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsActiveKey) ?? false;
  }

  /// Clears stored state so a new alert can trigger immediately.
  /// Optionally clears the stopped flag to re-enable alerts.
  Future<void> resetState({bool clearStopped = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLastTriggerTs);
    await prefs.remove(_prefsLastThresholdKey);
    await prefs.setBool(_prefsActiveKey, false);
    if (clearStopped) {
      await prefs.setBool(_prefsStoppedKey, false);
    }
  }

  /// Handles action buttons coming from Awesome Notifications.
  @pragma('vm:entry-point')
  Future<void> handleAction(ReceivedAction action) async {
    switch (action.buttonKeyPressed) {
      case _snoozeActionKey:
        await _handleSnoozeAction();
        break;
      case _dismissActionKey:
        await _handleDismissAction();
        break;
      case _stopActionKey:
        await _handleStopAction();
        break;
      default:
        // If no button was pressed (notification body tapped), just stop the alert
        await stopAlert(clearCooldown: true);
    }
  }

  static const String _snoozeActionKey = 'SNOOZE_THRESHOLD_ALERT';
  static const String _dismissActionKey = 'DISMISS_THRESHOLD_ALERT';
  static const String _stopActionKey = 'STOP_THRESHOLD_ALERT';

  Future<void> _handleSnoozeAction() async {
    await _setSnoozedUntil(DateTime.now().add(_defaultSnoozeDuration));
    await stopAlert(clearCooldown: false);
    AppLogger.i(
      '[ThresholdAlertService] Alert snoozed for ${_defaultSnoozeDuration.inMinutes} minutes.',
    );
  }

  Future<void> _handleDismissAction() async {
    await _clearSnooze();
    await stopAlert(clearCooldown: true);
    AppLogger.i('[ThresholdAlertService] Alert dismissed by user.');
  }

  Future<void> _handleStopAction() async {
    final prefs = await SharedPreferences.getInstance();

    // Set stopped flag to prevent future notifications
    await prefs.setBool(_prefsStoppedKey, true);

    await _clearSnooze();
    await stopAlert(clearCooldown: true);
    await resetState();

    AppLogger.i(
      '[ThresholdAlertService] Alert stopped by user - notification loop disabled.',
    );
  }

  /// Re-enable alerts after they were stopped
  Future<void> enableAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsStoppedKey, false);
    AppLogger.i('[ThresholdAlertService] Alerts re-enabled.');
  }

  /// Check if alerts are currently stopped
  Future<bool> isAlertsStopped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsStoppedKey) ?? false;
  }

  Future<void> _setSnoozedUntil(DateTime until) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(snoozePrefsKey, until.millisecondsSinceEpoch);
  }

  Future<void> _clearSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(snoozePrefsKey);
  }

  Future<bool> _canTriggerAfterSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    final snoozedUntilMs = prefs.getInt(snoozePrefsKey);
    if (snoozedUntilMs == null) return true;

    final snoozedUntil = DateTime.fromMillisecondsSinceEpoch(
      snoozedUntilMs,
      isUtc: false,
    );
    if (DateTime.now().isBefore(snoozedUntil)) {
      return false;
    }
    await _clearSnooze();
    return true;
  }

  Future<void> _startNativeAudio() async {
    try {
      await _platformChannel.invokeMethod('startAlertService');
    } catch (e) {
      AppLogger.e(
        '[ThresholdAlertService] ❌ Failed to start native alert audio: $e',
      );
    }
  }

  Future<void> _stopNativeAudio() async {
    try {
      await _platformChannel.invokeMethod('stopAlertService');
    } catch (e) {
      AppLogger.e(
        '[ThresholdAlertService] ❌ Failed to stop native alert audio: $e',
      );
    }
  }
}
