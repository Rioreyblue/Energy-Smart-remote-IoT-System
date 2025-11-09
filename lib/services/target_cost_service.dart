import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Service for managing budget target data from Firestore
class TargetCostService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  StreamSubscription<DocumentSnapshot>? _targetCostSubscription;
  double _targetCost = 0.0;
  double _totalBudget = 0.0;
  double _remainingBudget = 0.0;
  double _ratePerKwh = 12.50;
  double _thresholdPercentage = 80.0;
  bool _alertEnabled = true;
  bool _isLoading = true;
  String? _error;
  bool _hasTarget = false;

  // Getters
  double get targetCost => _targetCost; // Backward compatibility
  double get totalBudget => _totalBudget;
  double get remainingBudget => _remainingBudget;
  double get ratePerKwh => _ratePerKwh;
  double get thresholdPercentage => _thresholdPercentage;
  bool get alertEnabled => _alertEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasTarget => _hasTarget;
  String get formattedTargetCost => '₱${_targetCost.toStringAsFixed(2)}';

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Get Realtime DB reference for target cost sync
  DatabaseReference get _targetCostRealtimeRef =>
      _database.ref('users/$_userId/target_threshold/target_cost');

  /// Initialize the service and start listening to target cost changes
  void initialize() {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _targetCostSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .collection('budget_target')
        .doc('current')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              _totalBudget = (data['totalBudget'] ?? 0.0).toDouble();
              _remainingBudget = (data['remainingBudget'] ?? 0.0).toDouble();
              _ratePerKwh = (data['ratePerKwh'] ?? 12.50).toDouble();
              _thresholdPercentage =
                  (data['thresholdPercentage'] ?? 80.0).toDouble();
              _alertEnabled = data['alertEnabled'] ?? true;
              _targetCost = _totalBudget; // Backward compatibility
              _hasTarget = _totalBudget > 0;
              _error = null;
            } else {
              _targetCost = 0.0;
              _totalBudget = 0.0;
              _remainingBudget = 0.0;
              _ratePerKwh = 12.50;
              _thresholdPercentage = 80.0;
              _alertEnabled = true;
              _hasTarget = false;
              _error = null;
            }
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load budget data: ${error.toString()}';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Update target cost in Firestore (primary) and sync to Realtime DB
  Future<bool> updateTargetCost(double newTargetCost) async {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Save to Firestore (primary source)
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('budget_target')
          .doc('current')
          .set({
            'totalBudget': newTargetCost,
            'remainingBudget': newTargetCost, // Reset remaining to match total
            'ratePerKwh': _ratePerKwh,
            'thresholdPercentage': _thresholdPercentage,
            'alertEnabled': _alertEnabled,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Also save to target_threshold collection for consistency with EnergyDashboardController
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('target_threshold')
          .doc('target_cost')
          .set({
            'target_cost': newTargetCost,
            'totalBudget': newTargetCost,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Sync to Realtime DB for real-time updates
      await _targetCostRealtimeRef.set(newTargetCost);

      _targetCost = newTargetCost;
      _totalBudget = newTargetCost;
      _remainingBudget = newTargetCost;
      _hasTarget = _targetCost > 0;
      _isLoading = false;
      _error = null;
      AppLogger.i(
        '[TargetCostService] Updated target cost: $newTargetCost (synced to both Firestore and Realtime DB)',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update budget data: ${e.toString()}';
      _isLoading = false;
      AppLogger.e('[TargetCostService] Error updating target cost: $e');
      notifyListeners();
      return false;
    }
  }

  /// Create initial target cost document in Firestore and sync to Realtime DB
  Future<bool> createInitialTargetCost(double targetCost) async {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Save to Firestore (primary source)
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('budget_target')
          .doc('current')
          .set({
            'totalBudget': targetCost,
            'remainingBudget': targetCost,
            'ratePerKwh': 12.50,
            'thresholdPercentage': 80.0,
            'alertEnabled': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      // Also save to target_threshold collection for consistency
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('target_threshold')
          .doc('target_cost')
          .set({
            'target_cost': targetCost,
            'totalBudget': targetCost,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Sync to Realtime DB
      await _targetCostRealtimeRef.set(targetCost);

      _targetCost = targetCost;
      _totalBudget = targetCost;
      _remainingBudget = targetCost;
      _ratePerKwh = 12.50;
      _thresholdPercentage = 80.0;
      _alertEnabled = true;
      _hasTarget = true;
      _isLoading = false;
      _error = null;
      AppLogger.i(
        '[TargetCostService] Created initial target cost: $targetCost',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create budget data: ${e.toString()}';
      _isLoading = false;
      AppLogger.e('[TargetCostService] Error creating target cost: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete target cost
  Future<bool> deleteTargetCost() async {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('budget_target')
          .doc('current')
          .delete();

      _targetCost = 0.0;
      _totalBudget = 0.0;
      _remainingBudget = 0.0;
      _ratePerKwh = 12.50;
      _thresholdPercentage = 80.0;
      _alertEnabled = true;
      _hasTarget = false;
      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete budget data: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get target cost percentage of current usage
  double getTargetPercentage(double currentCost) {
    if (_targetCost == 0 || currentCost == 0) return 0.0;
    return (currentCost / _targetCost) * 100;
  }

  /// Check if current cost exceeds target
  bool isOverTarget(double currentCost) {
    return currentCost > _targetCost;
  }

  /// Get remaining budget (calculated from current cost)
  double getRemainingBudget(double currentCost) {
    return _targetCost - currentCost;
  }

  /// Update remaining budget in Firestore and sync to Realtime DB
  Future<bool> updateRemainingBudget(double remaining) async {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('budget_target')
          .doc('current')
          .update({
            'remainingBudget': remaining,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      // Note: We don't sync remaining budget to Realtime DB target_cost
      // target_cost is the total budget, not the remaining budget
      // Remaining budget is only stored in Firestore

      _remainingBudget = remaining;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update remaining budget: ${e.toString()}';
      AppLogger.e('[TargetCostService] Error updating remaining budget: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get all budget data as a map
  Map<String, dynamic> getBudgetData() {
    return {
      'totalBudget': _totalBudget,
      'remainingBudget': _remainingBudget,
      'ratePerKwh': _ratePerKwh,
      'thresholdPercentage': _thresholdPercentage,
      'alertEnabled': _alertEnabled,
    };
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh data
  Future<void> refresh() async {
    initialize();
  }

  @override
  void dispose() {
    _targetCostSubscription?.cancel();
    super.dispose();
  }
}
