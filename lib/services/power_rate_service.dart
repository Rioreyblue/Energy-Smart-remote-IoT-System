import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';

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
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  final NotificationService _notificationService = NotificationService();

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

      // Initialize previous rate after first fetch
      _previousRate = _currentRate;

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
    }

    AppLogger.i('[PowerRateService] Power rate updated to: $_currentRate');
    if (!_rateController.isClosed) {
      _rateController.add(_currentRate);
    }
    notifyListeners();
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
