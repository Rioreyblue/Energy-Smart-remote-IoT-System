import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import '../utils/app_logger.dart';
import 'threshold_alert_service.dart';
import 'notification_service.dart';

const String kThresholdMonitorTask = 'threshold_monitor_task';
const String _kThresholdMonitorUnique = 'threshold_monitor_unique';
const String kChatMonitorTask = 'chat_monitor_task';
const String _kChatMonitorUnique = 'chat_monitor_unique';
const String _kChatLastAlertPrefix = 'chat_last_alert_';
const String kRateMonitorTask = 'rate_monitor_task';
const String _kRateMonitorUnique = 'rate_monitor_unique';
const String _kRateLastAlertPrefix = 'rate_last_alert_';

bool _workmanagerInitialized = false;

Future<void> _ensureWorkmanagerInitialized() async {
  if (_workmanagerInitialized) return;
  await Workmanager().initialize(thresholdMonitorCallbackDispatcher);
  _workmanagerInitialized = true;
}

@pragma('vm:entry-point')
void thresholdMonitorCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      switch (taskName) {
        case kThresholdMonitorTask:
          await ThresholdMonitorTask().run();
          break;
        case kChatMonitorTask:
          await ChatMonitorTask().run();
          break;
        case kRateMonitorTask:
          await RateMonitorTask().run();
          break;
        default:
          AppLogger.w('[BackgroundTask] Unknown task received: $taskName');
      }
    } catch (e) {
      AppLogger.e('[BackgroundTask] Error executing $taskName: $e');
    }
    return true;
  });
}

class ThresholdMonitorService {
  ThresholdMonitorService._();

  static final ThresholdMonitorService instance = ThresholdMonitorService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _ensureWorkmanagerInitialized();
    _initialized = true;
  }

  Future<void> registerBackgroundTask() async {
    if (!_initialized) {
      await initialize();
    }

    await Workmanager().registerPeriodicTask(
      _kThresholdMonitorUnique,
      kThresholdMonitorTask,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
      ),
    );
    AppLogger.i('[ThresholdMonitorService] Background task registered.');
  }

  Future<void> cancelBackgroundTask() async {
    if (!_initialized) return;
    await Workmanager().cancelByUniqueName(_kThresholdMonitorUnique);
    AppLogger.i('[ThresholdMonitorService] Background task cancelled.');
  }

  /// Allows foreground code to trigger a manual threshold check.
  Future<void> runImmediateCheck() async {
    await ThresholdMonitorTask().run();
  }
}

class ThresholdMonitorTask {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<void> run() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.w(
          '[ThresholdMonitorTask] Skipping check - no authenticated user.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final snoozedUntilMs = prefs.getInt(ThresholdAlertService.snoozePrefsKey);
      if (snoozedUntilMs != null) {
        final snoozedUntil = DateTime.fromMillisecondsSinceEpoch(
          snoozedUntilMs,
        );
        if (DateTime.now().isBefore(snoozedUntil)) {
          AppLogger.i(
            '[ThresholdMonitorTask] Snoozed until $snoozedUntil - skipping.',
          );
          return;
        } else {
          await prefs.remove(ThresholdAlertService.snoozePrefsKey);
        }
      }

      // Check if alerts are permanently stopped
      final alertsStoppedLocally =
          prefs.getBool(ThresholdAlertService.stoppedPrefsKey) ?? false;
      if (alertsStoppedLocally) {
        AppLogger.i(
          '[ThresholdMonitorTask] Alerts permanently stopped locally - skipping notification loop.',
        );
        return;
      }

      // Check if alerts are temporarily dismissed
      // Note: If threshold is reached, triggerAlert will auto-resume by clearing dismissed flag
      final alertsDismissedLocally =
          prefs.getBool(ThresholdAlertService.dismissedPrefsKey) ?? false;
      if (alertsDismissedLocally) {
        AppLogger.d(
          '[ThresholdMonitorTask] Alerts dismissed locally (temporary pause). '
          'Will auto-resume when threshold is reached again.',
        );
        // Continue to check threshold - if reached, triggerAlert will auto-resume
      }

      // OneSignal is initialized automatically when needed
      // No need to ensure channel ready (that was for AwesomeNotifications)

      final budgetDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('budget_target')
              .doc('current')
              .get();

      if (!budgetDoc.exists) {
        AppLogger.w('[ThresholdMonitorTask] No budget target document.');
        return;
      }

      final data = budgetDoc.data() ?? {};
      final totalBudget = (data['totalBudget'] as num?)?.toDouble() ?? 0.0;
      if (totalBudget <= 0) {
        AppLogger.w('[ThresholdMonitorTask] Total budget is zero.');
        return;
      }

      final thresholdPercentage =
          (data['thresholdPercentage'] as num?)?.toDouble() ?? 80.0;
      final alertEnabled = data['alertEnabled'] != false;

      if (!alertEnabled) {
        AppLogger.d('[ThresholdMonitorTask] Alerts disabled - skipping.');
        return;
      }

      // Check if alerts are permanently stopped - fully override notification loop
      final alertsStopped = data['alertsStopped'] ?? false;
      if (alertsStopped) {
        AppLogger.i(
          '[ThresholdMonitorTask] Alerts permanently stopped by user - notification loop disabled.',
        );
        return;
      }

      // Check if alerts are temporarily dismissed
      // Note: If threshold is reached, triggerAlert will auto-resume by clearing dismissed flag
      final alertsDismissed = data['alertsDismissed'] ?? false;
      if (alertsDismissed) {
        AppLogger.d(
          '[ThresholdMonitorTask] Alerts dismissed (temporary pause). '
          'Will auto-resume when threshold is reached again.',
        );
        // Continue to check threshold - if reached, triggerAlert will auto-resume
      }

      // Check if alerts are snoozed - override notification loop until snooze expires
      final snoozedUntil = (data['snoozedUntil'] as Timestamp?)?.toDate();
      if (snoozedUntil != null && DateTime.now().isBefore(snoozedUntil)) {
        AppLogger.i(
          '[ThresholdMonitorTask] Alerts snoozed until ${snoozedUntil.toIso8601String()} - skipping.',
        );
        return;
      }

      double remainingBudget =
          (data['remainingBudget'] as num?)?.toDouble() ?? totalBudget;

      if (remainingBudget == totalBudget || remainingBudget == 0) {
        // Attempt to fetch more up-to-date value from Realtime DB.
        final remainingSnap =
            await _database
                .ref('users/${user.uid}/target_threshold/remaining_budget')
                .get();
        remainingBudget =
            (remainingSnap.value as num?)?.toDouble() ?? remainingBudget;
      }

      final consumedCost = (totalBudget - remainingBudget).clamp(
        0.0,
        totalBudget,
      );
      final usagePercent =
          totalBudget == 0 ? 0 : (consumedCost / totalBudget * 100);

      if (usagePercent >= thresholdPercentage) {
        await ThresholdAlertService.instance.triggerAlert(
          consumedCost: consumedCost,
          totalBudget: totalBudget,
          remainingBudget: remainingBudget,
          thresholdPercentage: thresholdPercentage,
        );
      } else {
        final active = await ThresholdAlertService.instance.isAlertActive();
        if (active) {
          await ThresholdAlertService.instance.stopAlert();
        }
      }
    } catch (e) {
      AppLogger.e('[ThresholdMonitorTask] Error running background check: $e');
    }
  }
}

class ChatMonitorService {
  ChatMonitorService._();

  static final ChatMonitorService instance = ChatMonitorService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _ensureWorkmanagerInitialized();
    _initialized = true;
  }

  Future<void> registerBackgroundTask() async {
    await initialize();

    await Workmanager().registerPeriodicTask(
      _kChatMonitorUnique,
      kChatMonitorTask,
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(minutes: 10),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    AppLogger.i('[ChatMonitorService] Background chat task registered.');
  }

  Future<void> cancelBackgroundTask() async {
    if (!_initialized) return;
    await Workmanager().cancelByUniqueName(_kChatMonitorUnique);
    AppLogger.i('[ChatMonitorService] Background chat task cancelled.');
  }
}

class ChatMonitorTask {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> run() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.w('[ChatMonitorTask] No authenticated user, skipping.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final query =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: user.uid)
              .limit(5)
              .get();

      if (query.docs.isEmpty) {
        return;
      }

      final notificationService = NotificationService();
      await notificationService.ensureInitializedForBackground();

      for (final doc in query.docs) {
        final data = doc.data();
        final unread =
            ((data['unreadCount'] as Map?)?[user.uid] as num?)?.toInt() ?? 0;
        if (unread <= 0) continue;

        final chatId = doc.id;
        final lastMessageTime =
            (data['lastMessageTime'] as Timestamp?)?.toDate();
        final lastAlertKey = '$_kChatLastAlertPrefix$chatId';
        final lastAlertMs = prefs.getInt(lastAlertKey);
        if (lastMessageTime != null &&
            lastAlertMs != null &&
            lastMessageTime.millisecondsSinceEpoch <= lastAlertMs) {
          continue;
        }

        final messageSnap =
            await _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();

        if (messageSnap.docs.isEmpty) continue;
        final messageData = messageSnap.docs.first.data();
        final senderId = messageData['senderId'] as String?;
        if (senderId == null || senderId == user.uid) continue;

        final metadata = messageData['metadata'] as Map<String, dynamic>?;
        if (metadata != null && metadata['unsent'] == true) continue;
        if ((messageData['type'] as String?) == 'system') continue;

        String senderName =
            (messageData['senderName'] as String?)?.trim() ?? '';
        if (senderName.isEmpty) {
          senderName = 'Support';
        }

        final messageType =
            (messageData['type'] ?? 'text').toString().toLowerCase();
        String preview = (messageData['text'] ?? '').toString().trim();
        if (messageType == 'image') {
          preview = '📷 Image';
        } else if (messageType == 'file') {
          final attachments = messageData['attachments'];
          if (attachments is List && attachments.isNotEmpty) {
            final first = attachments.first;
            final name =
                first is Map<String, dynamic> ? first['name'] as String? : null;
            preview = '📎 ${name ?? 'Attachment'}';
          } else {
            preview = '📎 Attachment';
          }
        } else if (preview.isEmpty) {
          preview = 'You have a new message';
        } else if (preview.length > 80) {
          preview = '${preview.substring(0, 80)}…';
        }

        await notificationService.showChatMessageNotification(
          senderName: senderName,
          messagePreview: preview,
          chatId: chatId,
          messageId: messageSnap.docs.first.id,
        );

        final timestampToStore =
            lastMessageTime?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(lastAlertKey, timestampToStore);
      }
    } catch (e) {
      AppLogger.e('[ChatMonitorTask] Error running background chat check: $e');
    }
  }
}

class RateMonitorService {
  RateMonitorService._();

  static final RateMonitorService instance = RateMonitorService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _ensureWorkmanagerInitialized();
    _initialized = true;
  }

  Future<void> registerBackgroundTask() async {
    await initialize();

    await Workmanager().registerPeriodicTask(
      _kRateMonitorUnique,
      kRateMonitorTask,
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(minutes: 10),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    AppLogger.i(
      '[RateMonitorService] Background rate monitor task registered.',
    );
  }

  Future<void> cancelBackgroundTask() async {
    if (!_initialized) return;
    await Workmanager().cancelByUniqueName(_kRateMonitorUnique);
    AppLogger.i('[RateMonitorService] Background rate monitor task cancelled.');
  }
}

class RateMonitorTask {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> run() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.w('[RateMonitorTask] No authenticated user, skipping.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final notificationService = NotificationService();
      await notificationService.ensureInitializedForBackground();

      // Get current rate from Firestore
      final rateDoc =
          await _firestore
              .collection('admin_settings')
              .doc('system_config')
              .get();

      if (!rateDoc.exists) {
        AppLogger.w('[RateMonitorTask] Rate document not found.');
        return;
      }

      final data = rateDoc.data();
      if (data == null || data['powerRate'] == null) {
        AppLogger.w('[RateMonitorTask] Power rate not found in document.');
        return;
      }

      final currentRate = (data['powerRate'] as num).toDouble();
      final lastAlertKey = '$_kRateLastAlertPrefix${user.uid}';
      final lastRateKey = '${_kRateLastAlertPrefix}last_rate_${user.uid}';

      // Get last known rate
      final lastRate = prefs.getDouble(lastRateKey);
      final lastAlertMs = prefs.getInt(lastAlertKey);
      final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();

      // Check if rate has changed
      if (lastRate != null && (currentRate - lastRate).abs() < 0.00005) {
        AppLogger.d('[RateMonitorTask] Rate unchanged, skipping notification.');
        return;
      }

      // Check if we've already notified for this update
      if (lastUpdated != null && lastAlertMs != null) {
        final lastUpdatedMs = lastUpdated.millisecondsSinceEpoch;
        if (lastUpdatedMs <= lastAlertMs) {
          AppLogger.d(
            '[RateMonitorTask] Already notified for this rate update, skipping.',
          );
          return;
        }
      }

      // Show notification if rate changed
      if (lastRate != null) {
        await notificationService.showRateUpdateNotification(
          oldRate: lastRate,
          newRate: currentRate,
        );

        // Store the current rate and alert timestamp
        await prefs.setDouble(lastRateKey, currentRate);
        final timestampToStore =
            lastUpdated?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(lastAlertKey, timestampToStore);

        AppLogger.i(
          '[RateMonitorTask] Rate update notification sent: ₱$lastRate → ₱$currentRate',
        );
      } else {
        // First time - just store the rate without notification
        await prefs.setDouble(lastRateKey, currentRate);
        AppLogger.d('[RateMonitorTask] Initial rate stored: ₱$currentRate');
      }
    } catch (e) {
      AppLogger.e('[RateMonitorTask] Error running background rate check: $e');
    }
  }
}
