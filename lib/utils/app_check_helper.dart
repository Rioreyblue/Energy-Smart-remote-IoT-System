import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../utils/app_logger.dart';

class AppCheckHelper {
  AppCheckHelper._();

  static const Duration _defaultTimeout = Duration(seconds: 6);

  /// Ensure an App Check token is available and valid.
  /// Optionally forces a refresh. Retries a few times for robustness.
  static Future<bool> ensureReady({bool forceRefresh = false}) async {
    final appCheck = FirebaseAppCheck.instance;
    const int maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final tokenFuture = appCheck.getToken(forceRefresh);
        final token = await tokenFuture.timeout(_defaultTimeout);

        if (token != null && token.isNotEmpty) {
          if (kDebugMode) {
            AppLogger.i('[AppCheck] ✅ Token acquired (len=${token.length})');
          }
          return true;
        }

        if (kDebugMode) {
          AppLogger.w(
            '[AppCheck] ⚠️ Token empty on attempt $attempt/$maxAttempts',
          );
        }
      } on TimeoutException {
        AppLogger.w('[AppCheck] ⏱️ getToken() timed out on attempt $attempt');
      } catch (e) {
        AppLogger.w('[AppCheck] ⚠️ getToken() failed on attempt $attempt: $e');
      }

      // Brief backoff before retry
      await Future.delayed(Duration(milliseconds: 300 * attempt));
      // After first attempt, try forcing refresh
      forceRefresh = true;
    }

    AppLogger.w('[AppCheck] ❌ Unable to obtain App Check token after retries');
    return false;
  }

  /// Try to fetch and log token once (best-effort), without impacting flow.
  static Future<void> logTokenOnce() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) {
          AppLogger.i('[AppCheck] 🔑 Token preview len=${token.length}');
        }
      } else {
        AppLogger.w('[AppCheck] ⚠️ Token is null/empty when logging');
      }
    } catch (e) {
      AppLogger.w('[AppCheck] ⚠️ Failed to log token: $e');
    }
  }
}
