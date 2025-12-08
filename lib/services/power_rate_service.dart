import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';
import 'sms_chef_service.dart';
import 'auth_service.dart';

/// Service for managing power rate from admin settings
class PowerRateService extends ChangeNotifier {
  static final PowerRateService _instance = PowerRateService._internal();
  factory PowerRateService() => _instance;
  PowerRateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<double> _rateController =
      StreamController<double>.broadcast();

  StreamSubscription<DocumentSnapshot>? _powerRateSubscription;
  double _currentRate = 12.50; // Default fallback rate
  double? _previousRate; // Track previous rate for notifications
  double? _lastSmsSentRate; // Track last rate that triggered SMS
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  final NotificationService _notificationService = NotificationService();
  final SmsChefService _smsChefService = SmsChefService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Getters
  double get currentRate => _currentRate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<double> get rateStream => _rateController.stream;

  /// Initialize and load power rate from Firestore
  Future<void> initialize() async {
    if (_isInitialized) {
      await _fetchCurrentRate();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.d(
        '[PowerRateService] Loading power rate from admin settings...',
      );

      await _fetchCurrentRate();

      // Initialize previous rate after first fetch (don't send SMS on initial load)
      _previousRate = _currentRate;
      _lastSmsSentRate = _currentRate; // Mark current rate as already notified

      // Set up real-time listener for power rate changes
      _powerRateSubscription?.cancel();
      _powerRateSubscription = _firestore
          .collection('admin_settings')
          .doc('system_config')
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists) {
                final data = snapshot.data();
                if (data != null && data['powerRate'] != null) {
                  final newRate = (data['powerRate'] as num).toDouble();
                  _updateRate(newRate);
                }
              }
            },
            onError: (error) {
              AppLogger.e(
                '[PowerRateService] Error listening to power rate changes: $error',
              );
            },
          );

      AppLogger.i(
        '[PowerRateService] Real-time power rate listener initialized',
      );
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
      AppLogger.e('[PowerRateService] Error loading power rate: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh power rate from Firestore
  Future<void> refresh() async {
    await _fetchCurrentRate();
  }

  /// Get current power rate
  double getCurrentRate() {
    return _currentRate;
  }

  /// Set power rate (for admin use)
  Future<bool> setPowerRate(double rate) async {
    try {
      await _firestore.collection('admin_settings').doc('system_config').set({
        'powerRate': rate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _updateRate(rate);
      AppLogger.i('[PowerRateService] ✅ Power rate updated to: $rate');
      return true;
    } catch (e) {
      AppLogger.e('[PowerRateService] ❌ Error setting power rate: $e');
      return false;
    }
  }

  Future<void> _fetchCurrentRate() async {
    try {
      final doc =
          await _firestore
              .collection('admin_settings')
              .doc('system_config')
              .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['powerRate'] != null) {
          final fetchedRate = (data['powerRate'] as num).toDouble();
          _updateRate(fetchedRate);
          return;
        }
        AppLogger.w(
          '[PowerRateService] powerRate field not found, using default',
        );
      } else {
        AppLogger.w(
          '[PowerRateService] Admin settings document not found, using default',
        );
      }
    } catch (e) {
      _error = e.toString();
      AppLogger.e('[PowerRateService] Error fetching power rate: $e');
    }
  }

  void _updateRate(double rawRate) {
    final normalizedRate = double.parse(rawRate.toStringAsFixed(4));
    if ((normalizedRate - _currentRate).abs() < 0.00005) {
      return;
    }

    // Store previous rate before updating
    _previousRate = _currentRate;
    _currentRate = normalizedRate;

    // Trigger notification if rate actually changed and we have a previous rate
    if (_previousRate != null &&
        (normalizedRate - _previousRate!).abs() >= 0.00005) {
      _notificationService.showRateUpdateNotification(
        oldRate: _previousRate!,
        newRate: normalizedRate,
      );

      // Send SMS alert for power rate update (only once per rate change)
      // Check if SMS was already sent for this specific rate change
      if (_lastSmsSentRate == null ||
          (_lastSmsSentRate! - normalizedRate).abs() >= 0.00005) {
        _sendPowerRateUpdateSms(
          oldRate: _previousRate!,
          newRate: normalizedRate,
        );
        _lastSmsSentRate = normalizedRate; // Mark this rate as notified
      }
    }

    AppLogger.i('[PowerRateService] Power rate updated to: $_currentRate');
    if (!_rateController.isClosed) {
      _rateController.add(_currentRate);
    }
    notifyListeners();
  }

  /// Format phone number to international format (+63...) for SMS Chef
  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.isEmpty) {
      throw Exception('Invalid phone number: No digits found');
    }

    // Already in international format
    if (cleaned.startsWith('+63')) {
      return cleaned;
    }

    // Philippine number starting with 0 (e.g., 09123456789)
    if (cleaned.startsWith('0') && cleaned.length >= 11) {
      return '+63${cleaned.substring(1)}';
    }

    // Philippine number starting with 63 (e.g., 639123456789)
    if (cleaned.startsWith('63') && cleaned.length >= 12) {
      return '+$cleaned';
    }

    // If it's 10 digits, assume it's a local PH number and add +63
    if (cleaned.length == 10) {
      return '+63$cleaned';
    }

    // If it's 11 digits and doesn't start with 0, assume it's already without country code
    if (cleaned.length == 11 && !cleaned.startsWith('0')) {
      return '+63$cleaned';
    }

    // Fallback: try to add +63 prefix
    return '+63$cleaned';
  }

  /// Send SMS alert when power rate is updated
  Future<void> _sendPowerRateUpdateSms({
    required double oldRate,
    required double newRate,
  }) async {
    try {
      // Check if user is authenticated
      final userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        AppLogger.d(
          '[PowerRateService] User not authenticated - skipping SMS alert',
        );
        return;
      }

      // Get user's phone number from multiple sources
      String? phoneNumber;

      // Try Firebase Auth phone number first
      final authUser = _auth.currentUser;
      if (authUser?.phoneNumber != null && authUser!.phoneNumber!.isNotEmpty) {
        phoneNumber = authUser.phoneNumber;
        AppLogger.d('[PowerRateService] Using phone number from Firebase Auth');
      }

      // Fallback to user data from AuthService
      if (phoneNumber == null || phoneNumber.isEmpty) {
        final userData = await _authService.getCurrentUserData();
        if (userData != null) {
          phoneNumber = userData.mobileNumber;
          AppLogger.d('[PowerRateService] Using phone number from user data');
        }
      }

      if (phoneNumber == null || phoneNumber.isEmpty) {
        AppLogger.w(
          '[PowerRateService] Phone number not found in any source - cannot send SMS alert',
        );
        return;
      }

      AppLogger.d(
        '[PowerRateService] Retrieved phone number: ${phoneNumber.length > 4 ? phoneNumber.substring(phoneNumber.length - 4) : "****"}',
      );

      // Format phone number to international format (+63...) for SMS Chef
      try {
        phoneNumber = _formatPhoneNumber(phoneNumber);
        AppLogger.d(
          '[PowerRateService] Formatted phone number for SMS: ${phoneNumber.length > 4 ? phoneNumber.substring(0, phoneNumber.length - 4) + "****" : "****"}',
        );
      } catch (e) {
        AppLogger.e('[PowerRateService] ❌ Error formatting phone number: $e');
        return;
      }

      // Send SMS alert
      await _smsChefService.sendPowerRateUpdateAlert(
        phoneNumber: phoneNumber,
        oldRate: oldRate,
        newRate: newRate,
      );

      AppLogger.i(
        '[PowerRateService] ✅ Power rate update SMS alert sent successfully to ${phoneNumber.substring(phoneNumber.length - 4)}',
      );
    } on SmsChefException catch (e) {
      AppLogger.e(
        '[PowerRateService] ❌ Failed to send power rate update SMS alert: ${e.message}',
      );
    } catch (e) {
      AppLogger.e(
        '[PowerRateService] ❌ Error sending power rate update SMS alert: $e',
      );
    }
  }

  @override
  void dispose() {
    _powerRateSubscription?.cancel();
    _powerRateSubscription = null;
    if (!_rateController.isClosed) {
      _rateController.close();
    }
    super.dispose();
  }
}
