import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import '../constants/constant.dart';
import 'app_logger.dart';

/// Helper class for handling storage permissions
class PermissionHelper {
  PermissionHelper._();

  /// Request storage permissions for Android
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      // iOS handles permissions automatically
      return true;
    }

    try {
      // Android 13+ (API 33+) doesn't need storage permission for Downloads
      // Android 10-12 (API 29-32) needs WRITE_EXTERNAL_STORAGE
      // Android 6-9 (API 23-28) needs WRITE_EXTERNAL_STORAGE

      // Check if we're on Android 13+
      if (await _isAndroid13Plus()) {
        AppLogger.i(
          '[PermissionHelper] Android 13+, no storage permission needed',
        );
        return true;
      }

      // For Android 10-12, request WRITE_EXTERNAL_STORAGE
      final status = await Permission.storage.request();

      if (status.isGranted) {
        AppLogger.i('[PermissionHelper] Storage permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        AppLogger.w('[PermissionHelper] Storage permission permanently denied');
        return false;
      } else {
        AppLogger.w('[PermissionHelper] Storage permission denied');
        return false;
      }
    } catch (e) {
      AppLogger.e('[PermissionHelper] Error requesting permission: $e');
      return false;
    }
  }

  /// Check if storage permission is granted
  static Future<bool> isStoragePermissionGranted() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      if (await _isAndroid13Plus()) {
        return true;
      }

      final status = await Permission.storage.status;
      return status.isGranted;
    } catch (e) {
      AppLogger.e('[PermissionHelper] Error checking permission: $e');
      return false;
    }
  }

  /// Show permission rationale dialog
  static Future<bool> showPermissionRationale(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.info_outline, color: AppColor.accentGreen, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Storage Permission Required',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            content: Text(
              'Energy Smart needs storage permission to save your exported data files to the Downloads folder. This allows you to access your exported reports easily.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                ),
                child: Text('Grant Permission'),
              ),
            ],
          ),
    );

    if (result == true) {
      return await requestStoragePermission();
    }

    return false;
  }

  /// Open app settings
  static Future<bool> openAppSettingsPage() async {
    return await openAppSettings();
  }

  /// Check if Android version is 13+ (API 33+)
  static Future<bool> _isAndroid13Plus() async {
    if (!Platform.isAndroid) return false;

    try {
      // Android 13+ uses scoped storage by default
      // Downloads folder is accessible without special permissions
      // We can use a simpler check - if permission handler returns unavailable,
      // we're likely on Android 13+
      final status = await Permission.storage.status;
      // If status is unavailable, we're on Android 13+
      return status == PermissionStatus.denied;
    } catch (e) {
      // Default to requesting permission to be safe
      return false;
    }
  }
}
