import 'dart:io';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';
import '../utils/app_router.dart';

/// Service for managing OneSignal push notifications
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _initialized = false;
  String? _playerId;
  static const String _oneSignalAppId = '741790af-bbf1-4480-9c92-18352b884ea3';

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

      // Handle notification clicked/opened
      OneSignal.Notifications.addClickListener((event) {
        AppLogger.i(
          '[OneSignalService] Notification clicked: ${event.notification.notificationId}',
        );

        final additionalData = event.notification.additionalData;
        if (additionalData != null) {
          final type = additionalData['type'] as String?;

          if (type == 'threshold_reached' || type == 'budget_alert') {
            // Navigate to Goals page (tab index 2)
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
}

