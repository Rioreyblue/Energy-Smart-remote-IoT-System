import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  static const String _prefsActiveKey = 'threshold_alert_active';
  static const String _prefsLastTriggerTs = 'threshold_alert_last_trigger_ts';
  static const String _prefsLastThresholdKey =
      'threshold_alert_last_threshold_value';
  static const String snoozePrefsKey = 'threshold_alert_snoozed_until';
  static const String stoppedPrefsKey =
      'threshold_alert_stopped'; // Flag to permanently stop notification loop
  static const String dismissedPrefsKey =
      'threshold_alert_dismissed'; // Flag to temporarily pause notification loop (auto-resumes when threshold reached again)

  static const Duration _cooldown = Duration(minutes: 5);
  static const Duration _defaultSnoozeDuration = Duration(minutes: 5);

  /// Triggers an alert if cooldowns allow. Returns true if a new alert was shown.
  Future<bool> triggerAlert({
    required double consumedCost,
    required double totalBudget,
    required double remainingBudget,
    required double thresholdPercentage,
    bool force = false,
  }) async {
    // Ensure OneSignal is initialized
    if (!OneSignalService.instance.isInitialized) {
      await OneSignalService.instance.initialize();
    }

    final prefs = await SharedPreferences.getInstance();

    // Check if alerts were permanently stopped by user (Stop button)
    final isStopped = prefs.getBool(stoppedPrefsKey) ?? false;
    if (isStopped && !force) {
      AppLogger.i(
        '[ThresholdAlertService] Alerts permanently stopped by user - notification loop disabled.',
      );
      return false;
    }

    // Check if alerts were dismissed (temporary pause)
    // If threshold is reached again, auto-resume notifications by clearing dismissed flag
    final isDismissed = prefs.getBool(dismissedPrefsKey) ?? false;
    if (isDismissed && !force) {
      // Auto-resume: Clear dismissed flag when threshold is reached again
      // Also clear cooldown to allow immediate notification after auto-resume
      // This allows notifications to resume automatically when threshold is reached again
      AppLogger.i(
        '[ThresholdAlertService] Alerts were dismissed (temporary pause). '
        'Threshold reached again - auto-resuming notifications and clearing cooldown.',
      );
      await prefs.setBool(dismissedPrefsKey, false);
      await prefs.remove(
        _prefsLastTriggerTs,
      ); // Clear cooldown to allow immediate notification
      await prefs.remove(_prefsLastThresholdKey); // Clear threshold tracking
      await _clearDismissedInFirestore();
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

    // Use OneSignal for threshold alerts (requires REST API key for action buttons)
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
    // Cancel OneSignal notification if initialized
    if (OneSignalService.instance.isInitialized) {
      await OneSignalService.instance.cancelThresholdAlert();
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
      await prefs.setBool(stoppedPrefsKey, false);
    }
  }

  /// Handles action buttons coming from OneSignal notifications.
  /// This method is called by OneSignalService when action buttons are clicked.
  Future<void> handleAction(String actionId) async {
    switch (actionId) {
      case 'snooze':
        await _handleSnoozeAction();
        break;
      case 'dismiss':
        await _handleDismissAction();
        break;
      case 'stop':
        await _handleStopAction();
        break;
      default:
        // If no button was pressed (notification body tapped), just stop the alert
        await stopAlert(clearCooldown: true);
    }
  }

  Future<void> _handleSnoozeAction() async {
    await _setSnoozedUntil(DateTime.now().add(_defaultSnoozeDuration));
    await stopAlert(clearCooldown: false);
    AppLogger.i(
      '[ThresholdAlertService] Alert snoozed for ${_defaultSnoozeDuration.inMinutes} minutes.',
    );
  }

  Future<void> _handleDismissAction() async {
    final prefs = await SharedPreferences.getInstance();

    // Set dismissed flag (temporary pause) - NOT stopped flag
    // This allows notifications to auto-resume when threshold is reached again
    await prefs.setBool(dismissedPrefsKey, true);
    await prefs.setBool(stoppedPrefsKey, false); // Ensure stopped is false

    await _clearSnooze();
    await stopAlert(clearCooldown: true);
    await _markAlertsDismissedInFirestore();

    AppLogger.i(
      '[ThresholdAlertService] Alert dismissed by user - notification loop temporarily paused. '
      'Notifications will auto-resume when threshold is reached again.',
    );
  }

  Future<void> _handleStopAction() async {
    final prefs = await SharedPreferences.getInstance();

    // Set stopped flag to permanently prevent future notifications
    await prefs.setBool(stoppedPrefsKey, true);
    // Clear dismissed flag when stopping (stop takes precedence)
    await prefs.setBool(dismissedPrefsKey, false);

    await _clearSnooze();
    await stopAlert(clearCooldown: true);
    await resetState();
    await _markAlertsStoppedInFirestore();

    AppLogger.i(
      '[ThresholdAlertService] Alert permanently stopped by user - notification loop disabled. '
      'User must manually re-enable alerts.',
    );
  }

  /// Allows other services (e.g., OneSignal callbacks) to persist stop flag
  Future<void> markStoppedFromRemote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(stoppedPrefsKey, true);
      await prefs.setBool(
        dismissedPrefsKey,
        false,
      ); // Clear dismissed when stopping
      await _clearSnooze();
      await _markAlertsStoppedInFirestore();
      AppLogger.i(
        '[ThresholdAlertService] Stop flag persisted from remote action.',
      );
    } catch (e) {
      AppLogger.w(
        '[ThresholdAlertService] Failed to persist stop flag from remote: $e',
      );
    }
  }

  /// Allows other services (e.g., OneSignal callbacks) to persist dismiss flag
  Future<void> markDismissedFromRemote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(dismissedPrefsKey, true);
      await prefs.setBool(stoppedPrefsKey, false); // Ensure stopped is false
      await _clearSnooze();
      await _markAlertsDismissedInFirestore();
      AppLogger.i(
        '[ThresholdAlertService] Dismiss flag persisted from remote action.',
      );
    } catch (e) {
      AppLogger.w(
        '[ThresholdAlertService] Failed to persist dismiss flag from remote: $e',
      );
    }
  }

  /// Persist stopped state in Firestore so background checks also skip
  Future<void> _markAlertsStoppedInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('budget_target')
          .doc('current')
          .set({
            'alertsStopped': true,
            'alertsDismissed': false, // Clear dismissed when stopping
            'alertsStoppedAt': FieldValue.serverTimestamp(),
            'snoozedUntil': null,
          }, SetOptions(merge: true));

      AppLogger.i(
        '[ThresholdAlertService] alertsStopped flag stored in Firestore',
      );
    } catch (e) {
      AppLogger.w(
        '[ThresholdAlertService] Failed to persist alertsStopped to Firestore: $e',
      );
    }
  }

  /// Persist dismissed state in Firestore so background checks also skip
  Future<void> _markAlertsDismissedInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('budget_target')
          .doc('current')
          .set({
            'alertsDismissed': true,
            'alertsStopped': false, // Ensure stopped is false when dismissing
            'alertsDismissedAt': FieldValue.serverTimestamp(),
            'snoozedUntil': null,
          }, SetOptions(merge: true));

      AppLogger.i(
        '[ThresholdAlertService] alertsDismissed flag stored in Firestore',
      );
    } catch (e) {
      AppLogger.w(
        '[ThresholdAlertService] Failed to persist alertsDismissed to Firestore: $e',
      );
    }
  }

  /// Clear dismissed state in Firestore (called when auto-resuming)
  Future<void> _clearDismissedInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('budget_target')
          .doc('current')
          .set({'alertsDismissed': false}, SetOptions(merge: true));

      AppLogger.i(
        '[ThresholdAlertService] alertsDismissed flag cleared in Firestore (auto-resume)',
      );
    } catch (e) {
      AppLogger.w(
        '[ThresholdAlertService] Failed to clear alertsDismissed in Firestore: $e',
      );
    }
  }

  /// Re-enable alerts after they were stopped
  Future<void> enableAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(stoppedPrefsKey, false);
    await prefs.setBool(dismissedPrefsKey, false);
    await _clearDismissedInFirestore();
    AppLogger.i('[ThresholdAlertService] Alerts re-enabled.');
  }

  /// Check if alerts are currently stopped (permanent)
  Future<bool> isAlertsStopped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(stoppedPrefsKey) ?? false;
  }

  /// Check if alerts are currently dismissed (temporary)
  Future<bool> isAlertsDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(dismissedPrefsKey) ?? false;
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
