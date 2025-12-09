import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../utils/app_logger.dart';

/// Background handler for FCM messages (kept for SMS and other FCM-based services).
@pragma('vm:entry-point')
Future<void> pushNotificationBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationManager.instance.handleMessage(
    message,
    fromBackground: true,
  );
}

class PushNotificationManager {
  PushNotificationManager._();

  static final PushNotificationManager instance = PushNotificationManager._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (!_initialized) {
      await _configureFirebaseMessaging();
      await _registerTokenListeners();
      _initialized = true;
    }
  }

  Future<void> _configureFirebaseMessaging() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    AppLogger.i(
      '[PushNotificationManager] FCM Notification permission: ${settings.authorizationStatus}',
    );

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
    if (message.data.isEmpty) return;

    final type = message.data['type'];

    // FCM messages are now handled by OneSignal or other services
    // This manager is kept for FCM token management (SMS, etc.)
    AppLogger.d(
      '[PushNotificationManager] FCM message received (type: $type). '
      'Notifications are handled by OneSignal.',
    );

    // Handle SMS-related FCM messages if needed
    if (type == 'sms' || type == 'verification') {
      AppLogger.d(
        '[PushNotificationManager] SMS/Verification FCM message received',
      );
      // SMS notifications are handled by SmsChef service, not FCM
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];

    // Handle navigation for different FCM message types
    if (type == 'sms' || type == 'verification') {
      // SMS notifications are handled by SmsChef service
      AppLogger.d(
        '[PushNotificationManager] SMS/Verification notification tapped',
      );
    }
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
