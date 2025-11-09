import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Service for managing power rate from admin settings
class PowerRateService extends ChangeNotifier {
  static final PowerRateService _instance = PowerRateService._internal();
  factory PowerRateService() => _instance;
  PowerRateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _powerRateSubscription;
  double _currentRate = 12.50; // Default fallback rate
  bool _isLoading = false;
  String? _error;

  // Getters
  double get currentRate => _currentRate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize and load power rate from Firestore
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.d(
        '[PowerRateService] Loading power rate from admin settings...',
      );

      // Load initial rate
      final doc =
          await _firestore
              .collection('admin_settings')
              .doc('system_config')
              .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['powerRate'] != null) {
          _currentRate = (data['powerRate'] as num).toDouble();
          AppLogger.i('[PowerRateService] Loaded power rate: $_currentRate');
        } else {
          AppLogger.w(
            '[PowerRateService] powerRate field not found, using default',
          );
        }
      } else {
        AppLogger.w(
          '[PowerRateService] Admin settings document not found, using default',
        );
      }

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
                  if (newRate != _currentRate) {
                    _currentRate = newRate;
                    AppLogger.i(
                      '[PowerRateService] Power rate updated to: $_currentRate',
                    );
                    notifyListeners();
                  }
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
    await initialize();
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

      _currentRate = rate;
      notifyListeners();
      AppLogger.i(
        '[PowerRateService] ✅ [PowerRateService] Power rate updated to: $rate',
      );
      return true;
    } catch (e) {
      AppLogger.e(
        '[PowerRateService] ❌ [PowerRateService] Error setting power rate: $e',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _powerRateSubscription?.cancel();
    _powerRateSubscription = null;
    super.dispose();
  }
}
