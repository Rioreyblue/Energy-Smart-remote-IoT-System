import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../utils/app_logger.dart';
import '../utils/app_router.dart';

/// Budget alert notification channel id.
const String kBudgetAlertChannelId = 'energy_alerts';

/// Action id used for stopping an ongoing budget alert.
const String kStopAlertActionId = 'STOP_ALERT';

/// Background handler for FCM messages.
@pragma('vm:entry-point')
Future<void> pushNotificationBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationManager.instance.handleMessage(
    message,
    fromBackground: true,
  );
}

/// Background handler for local notification responses.
@pragma('vm:entry-point')
void pushNotificationBackgroundResponse(NotificationResponse response) {
  PushNotificationManager.instance.handleNotificationResponse(response);
}

class PushNotificationManager {
  PushNotificationManager._();

  static final PushNotificationManager instance = PushNotificationManager._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _localNotificationsConfigured = false;

  Future<void> initialize() async {
    if (!_initialized) {
      await _configureFirebaseMessaging();
      await _registerTokenListeners();
      _initialized = true;
    }

    if (!_localNotificationsConfigured) {
      await _configureLocalNotifications();
    }
  }

  Future<void> _configureFirebaseMessaging() async {
    if (!_localNotificationsConfigured) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      AppLogger.i(
        '[PushNotificationManager] Notification permission: ${settings.authorizationStatus}',
      );
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_storeToken);
    FirebaseMessaging.onMessage.listen(handleMessage);
    FirebaseMessaging.onBackgroundMessage(pushNotificationBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await _messaging.getToken();
        if (token != null) {
          await _storeToken(token);
        }
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await handleMessage(initialMessage);
      _handleNotificationTap(initialMessage);
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _storeToken(token);
    }
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final iosCategory = DarwinNotificationCategory(
      'BUDGET_ALERT',
      actions: [
        DarwinNotificationAction.plain(
          kStopAlertActionId,
          'Stop Alert',
          options: {DarwinNotificationActionOption.destructive},
        ),
      ],
      options: {DarwinNotificationCategoryOption.customDismissAction},
    );

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
      notificationCategories: [iosCategory],
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    final initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          pushNotificationBackgroundResponse,
    );

    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        kBudgetAlertChannelId,
        'Energy Alerts',
        description: 'Alerts when budget thresholds are reached',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1500, 600, 1500]),
      ),
    );
    _localNotificationsConfigured = true;
  }

  Future<void> _registerTokenListeners() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _storeToken(token);
    }
  }

  Future<void> handleMessage(
    RemoteMessage message, {
    bool fromBackground = false,
  }) async {
    if (!_localNotificationsConfigured) {
      await _configureLocalNotifications();
    }

    if (message.data.isEmpty) return;

    final type = message.data['type'];
    if (type == 'budget_alert') {
      await _handleBudgetAlert(message);
    }
  }

  Future<void> _handleBudgetAlert(RemoteMessage message) async {
    final data = message.data;
    final budgetName = data['budget_name'] ?? 'Budget Alert';
    final currentAmount = data['current_amount'] ?? '0';
    final totalBudget = data['budget_total'] ?? '0';
    final percentage = data['threshold_percentage'] ?? '0';
    final alertType = data['alert_type'] ?? 'threshold';
    final alertId = data['alert_id'] ?? DateTime.now().millisecondsSinceEpoch;

    final notificationId = alertId.hashCode & 0x7fffffff; // ensure positive int

    final title =
        alertType == 'total_budget' ? 'Total Budget Reached!' : 'Budget Alert';
    final body =
        'You\'ve reached ₱$currentAmount of ₱$totalBudget ($percentage%).';

    final payload = jsonEncode({
      ...data,
      'notification_id': notificationId.toString(),
    });

    final androidDetails = AndroidNotificationDetails(
      kBudgetAlertChannelId,
      'Energy Alerts',
      channelDescription: 'Alerts when budget thresholds are reached',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      vibrationPattern: Int64List.fromList([0, 1500, 600, 1500]),
      styleInformation: BigTextStyleInformation(''),
      actions: const [
        AndroidNotificationAction(
          kStopAlertActionId,
          'Stop Alert',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      categoryIdentifier: 'BUDGET_ALERT',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _localNotifications.show(
      notificationId,
      '$title • $budgetName',
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'budget_alert') {
      appRouter.go('/home?tab=2');
    }
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) {
      if (response.notificationResponseType ==
          NotificationResponseType.selectedNotification) {
        appRouter.go('/home?tab=2');
      }
      return;
    }

    final data = jsonDecode(payload) as Map<String, dynamic>;

    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      appRouter.go('/home?tab=2');
    }

    if (response.actionId == kStopAlertActionId) {
      await _handleStopAlert(data);
    }
  }

  static Future<void> _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    if (payload != null) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      await instance._handleStopAlert(data);
    }
  }

  Future<void> _handleStopAlert(Map<String, dynamic> data) async {
    final int? notificationId = int.tryParse(
      data['notification_id']?.toString() ?? '',
    );
    if (notificationId != null) {
      await _localNotifications.cancel(notificationId);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final budgetId = data['budget_id'] ?? 'current';
    final alertId = data['alert_id'];

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);

    if (alertId != null) {
      await userRef.collection('budget_alerts').doc(alertId.toString()).set({
        'dismissed': true,
        'dismissedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await userRef.collection('budget_target').doc(budgetId).set({
      'lastAlertDismissedAt': FieldValue.serverTimestamp(),
      'lastAlertDismissedType': data['alert_type'] ?? 'threshold',
    }, SetOptions(merge: true));
  }

  Future<void> _storeToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final tokenRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(token);

    await tokenRef.set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
