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

const String kThresholdMonitorTask = 'threshold_monitor_task';
const String _kThresholdMonitorUnique = 'threshold_monitor_unique';

@pragma('vm:entry-point')
void thresholdMonitorCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await ThresholdMonitorTask().run();
    return true;
  });
}

class ThresholdMonitorService {
  ThresholdMonitorService._();

  static final ThresholdMonitorService instance = ThresholdMonitorService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Workmanager().initialize(thresholdMonitorCallbackDispatcher);
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

      await ThresholdAlertService.instance.ensureChannelReady(
        fromBackground: true,
      );

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
