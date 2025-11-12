import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import 'device_control_service.dart';

/// Service for monitoring user account status in Firebase Realtime Database
/// Listens to users/{uid}/status for account suspension status
class UserStatusService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  StreamSubscription<DatabaseEvent>? _statusSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  // Status tracking
  String? _status;
  bool _isLoading = true;
  String? _error;

  // Getters
  String? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSuspended => _status?.toLowerCase() == 'suspended';
  bool get isActive => _status?.toLowerCase() == 'active';

  String get _userId => _auth.currentUser?.uid ?? '';

  UserStatusService() {
    // Listen to auth state changes to initialize/cleanup status listener
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        // User logged in, initialize status listener
        _initialize();
      } else {
        // User logged out, cleanup
        _disposeStatusListener();
        _status = null;
        _isLoading = false;
        _error = null;
        notifyListeners();
      }
    });

    // Initialize if user is already logged in
    if (_auth.currentUser != null) {
      _initialize();
    }
  }

  /// Initialize the service and start listening to status changes
  void _initialize() {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _disposeStatusListener(); // Cancel existing subscription if any

    _isLoading = true;
    _error = null;
    notifyListeners();

    AppLogger.d(
      '[UserStatusService] Initializing status listener for user: $_userId',
    );

    _statusSubscription = _database
        .ref('users/$_userId/status')
        .onValue
        .listen(
          (event) {
            _handleStatusUpdate(event);
          },
          onError: (error) {
            AppLogger.e(
              '[UserStatusService] Error listening to status: $error',
            );
            _error = 'Failed to load status: ${error.toString()}';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Handle status update from Firebase Realtime Database
  void _handleStatusUpdate(DatabaseEvent event) {
    final previousStatus = _status?.toLowerCase();
    try {
      if (event.snapshot.exists) {
        final statusValue = event.snapshot.value;

        if (statusValue != null) {
          _status = statusValue.toString().trim();
          AppLogger.d('[UserStatusService] Status updated: $_status');
        } else {
          // Status field exists but is null, treat as active
          _status = 'active';
          AppLogger.d(
            '[UserStatusService] Status is null, defaulting to active',
          );
        }
      } else {
        // Status field doesn't exist, treat as active
        _status = 'active';
        AppLogger.d(
          '[UserStatusService] Status field does not exist, defaulting to active',
        );
      }

      _error = null;
      _isLoading = false;
      notifyListeners();

      final currentStatus = _status?.toLowerCase();
      if (currentStatus == 'suspended' && previousStatus != 'suspended') {
        AppLogger.i(
          '[UserStatusService] Account suspended, disabling controllers.',
        );
        unawaited(DeviceControlService().turnOffAllControllers());
      }
    } catch (e) {
      AppLogger.e('[UserStatusService] Error handling status update: $e');
      _error = 'Failed to parse status: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dispose status listener
  void _disposeStatusListener() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  /// Manually refresh status (useful for testing or recovery)
  void refresh() {
    if (_userId.isNotEmpty) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _disposeStatusListener();
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
