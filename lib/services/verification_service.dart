import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling SMS/Phone verification with automatic resend functionality
class VerificationService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _countdownTimer;
  int _remainingSeconds = 180; // 3 minutes = 180 seconds
  bool _isVerifying = false;
  String? _verificationId;
  String? _error;
  bool _isResendEnabled = false;

  // Getters
  int get remainingSeconds => _remainingSeconds;
  bool get isVerifying => _isVerifying;
  String? get error => _error;
  bool get isResendEnabled => _isResendEnabled;
  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      _isVerifying = true;
      _error = null;
      notifyListeners();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          await _auth.signInWithCredential(credential);
          _isVerifying = false;
          notifyListeners();
        },
        verificationFailed: (FirebaseAuthException e) {
          _error = _getErrorMessage(e);
          _isVerifying = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _isVerifying = false;
          _startCountdownTimer();
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );

      return _verificationId != null;
    } catch (e) {
      _error = 'Failed to send OTP: ${e.toString()}';
      _isVerifying = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP code
  Future<bool> verifyOTP(String otpCode) async {
    if (_verificationId == null) {
      _error = 'No verification ID found. Please request a new OTP.';
      notifyListeners();
      return false;
    }

    try {
      _isVerifying = true;
      _error = null;
      notifyListeners();

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      await _auth.signInWithCredential(credential);
      _isVerifying = false;
      _stopCountdownTimer();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e as FirebaseAuthException);
      _isVerifying = false;
      notifyListeners();
      return false;
    }
  }

  /// Resend OTP (only available after timer expires)
  Future<bool> resendOTP(String phoneNumber) async {
    if (_isResendEnabled) {
      _resetTimer();
      return await sendOTP(phoneNumber);
    }
    return false;
  }

  /// Start the 3-minute countdown timer
  void _startCountdownTimer() {
    _remainingSeconds = 180;
    _isResendEnabled = false;
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _isResendEnabled = true;
        _stopCountdownTimer();
        notifyListeners();
      }
    });
  }

  /// Stop the countdown timer
  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Reset the timer
  void _resetTimer() {
    _stopCountdownTimer();
    _remainingSeconds = 180;
    _isResendEnabled = false;
    notifyListeners();
  }

  /// Get user-friendly error messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid verification code';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new code';
      case 'credential-already-in-use':
        return 'This phone number is already registered';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this phone number';
      default:
        return 'Verification failed: ${e.message}';
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _stopCountdownTimer();
    super.dispose();
  }
}


