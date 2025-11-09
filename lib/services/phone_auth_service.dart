import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:exercise_app/constants/app_config.dart';
import 'package:exercise_app/services/database_service.dart';
import 'package:exercise_app/services/sms_chef_service.dart';
import 'package:exercise_app/utils/app_logger.dart';

/// Phone Authentication Service backed by SMS Chef OTP delivery.
class PhoneAuthService extends ChangeNotifier {
  PhoneAuthService._internal() : _smsChefService = SmsChefService();

  static final PhoneAuthService _instance = PhoneAuthService._internal();

  factory PhoneAuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  SmsChefService _smsChefService;

  // State management
  bool _isVerifying = false;
  bool _isCodeSent = false;
  String? _error;
  String? _phoneNumber;
  String? _activeOtp;
  DateTime? _otpExpiry;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  // Getters
  bool get isVerifying => _isVerifying;
  bool get isCodeSent => _isCodeSent;
  String? get error => _error;
  String? get phoneNumber => _phoneNumber;
  int get remainingSeconds => _remainingSeconds;
  bool get canResend => _remainingSeconds == 0 && _isCodeSent;

  /// Format time as MM:SS
  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Send an OTP to the provided phone number.
  Future<bool> verifyPhoneNumber(String phoneNumber) async {
    String formattedPhone;
    try {
      formattedPhone = _formatPhoneNumber(phoneNumber);
    } on FormatException catch (e) {
      _error = e.message;
      _isVerifying = false;
      notifyListeners();
      return false;
    }

    AppLogger.d(
      '[PhoneAuthService] Initiating OTP send to ${_maskPhoneNumber(formattedPhone)}',
    );

    final wasCodeAlreadySent = _isCodeSent;

    _phoneNumber = formattedPhone;
    _isVerifying = true;
    _error = null;
    if (!wasCodeAlreadySent) {
      _isCodeSent = false;
    }
    notifyListeners();

    final otp = _generateOtp();

    try {
      await _smsChefService.sendOtp(
        phoneNumber: formattedPhone,
        otp: otp,
        expiry: AppConfig.smsOtpValidity,
      );

      _activeOtp = otp;
      _otpExpiry = DateTime.now().add(AppConfig.smsOtpValidity);
      _isCodeSent = true;
      _isVerifying = false;
      _startCountdownTimer(AppConfig.smsOtpValidity.inSeconds);
      notifyListeners();
      AppLogger.i('[PhoneAuthService] ✅ OTP sent successfully');
      return true;
    } on SmsChefException catch (e) {
      AppLogger.e('[PhoneAuthService] SmsChef failure: ${e.message}');
      _error = e.message;
    } catch (e) {
      AppLogger.e('[PhoneAuthService] Failed to send OTP: $e');
      _error = 'Failed to send verification code. Please try again.';
    } finally {
      _isVerifying = false;
      notifyListeners();
    }

    return false;
  }

  /// Verify OTP code sent to phone.
  Future<bool> verifyOTP(String smsCode) async {
    if (_activeOtp == null || _otpExpiry == null) {
      _error = 'No verification code found. Please request a new code.';
      notifyListeners();
      return false;
    }

    if (smsCode.length != 6) {
      _error = 'Please enter a valid 6-digit code.';
      notifyListeners();
      return false;
    }

    if (DateTime.now().isAfter(_otpExpiry!)) {
      _error = 'Verification code has expired. Please request a new one.';
      _isCodeSent = false;
      _activeOtp = null;
      _otpExpiry = null;
      notifyListeners();
      return false;
    }

    if (smsCode != _activeOtp) {
      _error = 'Invalid verification code. Please try again.';
      notifyListeners();
      return false;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _error = 'No authenticated user found. Please sign in again.';
      notifyListeners();
      return false;
    }

    _isVerifying = true;
    _error = null;
    notifyListeners();

    try {
      await _db.updateRealtimeUser(user.uid, {
        'isPhoneVerified': true,
        'mobileNumber': _phoneNumber,
      });

      await _db.saveUserProfile(user.uid, {
        'mobileNumber': _phoneNumber,
        'isPhoneVerified': true,
      });

      _stopCountdownTimer();
      _isVerifying = false;
      _isCodeSent = false;
      _activeOtp = null;
      _otpExpiry = null;
      notifyListeners();
      AppLogger.i('[PhoneAuthService] ✅ Phone verification successful');
      return true;
    } catch (e) {
      AppLogger.e(
        '[PhoneAuthService] Failed to update verification status: $e',
      );
      _error =
          'Verification succeeded but we could not update your profile. Please try again.';
      _isVerifying = false;
      notifyListeners();
      return false;
    }
  }

  /// Resend verification code.
  Future<bool> resendCode() async {
    if (_phoneNumber == null) {
      _error = 'Phone number not found. Please enter your phone number again.';
      notifyListeners();
      return false;
    }

    if (!canResend) {
      _error = 'Please wait before requesting a new code.';
      notifyListeners();
      return false;
    }

    return await verifyPhoneNumber(_phoneNumber!);
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset service state
  void reset() {
    _isVerifying = false;
    _isCodeSent = false;
    _error = null;
    _phoneNumber = null;
    _activeOtp = null;
    _otpExpiry = null;
    _stopCountdownTimer();
    notifyListeners();
  }

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
    reset();
    AppLogger.i('[PhoneAuthService] User signed out');
  }

  /// Allow overriding the SmsChefService (useful for tests).
  void setSmsService(SmsChefService service) {
    _smsChefService = service;
  }

  void _startCountdownTimer(int seconds) {
    _stopCountdownTimer();
    _remainingSeconds = seconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _stopCountdownTimer();
        notifyListeners();
      }
    });
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _remainingSeconds = 0;
  }

  String _generateOtp() {
    final random = Random.secure();
    final code = random.nextInt(900000) + 100000;
    return code.toString();
  }

  /// Format phone number to international format
  String _formatPhoneNumber(String phoneNumber) {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    if (sanitized.isEmpty) {
      throw const FormatException(
        'Enter a valid PH number (e.g. 09123456789 or +639123456789).',
      );
    }

    final normalized = sanitized.replaceAll(RegExp(r'[^0-9+]'), '');

    if (RegExp(r'^09\d{9}$').hasMatch(normalized)) {
      final digits = normalized.substring(1); // remove leading 0
      return '+63$digits';
    }

    if (RegExp(r'^\+639\d{9}$').hasMatch(normalized)) {
      return normalized;
    }

    if (normalized.startsWith('+')) {
      throw const FormatException(
        'Please enter a Philippine number starting with +63 or 09.',
      );
    }

    throw const FormatException(
      'Enter a valid PH number (e.g. 09123456789 or +639123456789).',
    );
  }

  /// Mask phone number for secure logging (shows only last 4 digits)
  String _maskPhoneNumber(String phoneNumber) {
    if (phoneNumber.length <= 4) return '****';
    final lastFour = phoneNumber.substring(phoneNumber.length - 4);
    final masked = '*' * (phoneNumber.length - 4);
    return '$masked$lastFour';
  }

  @override
  void dispose() {
    _stopCountdownTimer();
    super.dispose();
  }
}
