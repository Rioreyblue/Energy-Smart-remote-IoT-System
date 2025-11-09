import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/app_logger.dart';

/// Service for managing budget target data in Firestore
class FirestoreBudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Get Realtime Database reference for target threshold
  DatabaseReference get _targetThresholdRef =>
      _database.ref('users/$_userId/target_threshold');

  DocumentReference get _budgetRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('budget_target')
      .doc('current');

  /// Get current budget target
  Future<Map<String, dynamic>?> getBudgetTarget() async {
    try {
      final doc = await _budgetRef.get();
      if (doc.exists) {
        final data = doc.data()! as Map<String, dynamic>;
        return {
          'totalBudget': (data['totalBudget'] ?? 0.0).toDouble(),
          'remainingBudget': (data['remainingBudget'] ?? 0.0).toDouble(),
          'ratePerKwh': (data['ratePerKwh'] ?? 12.50).toDouble(),
          'thresholdPercentage':
              (data['thresholdPercentage'] ?? 80.0).toDouble(),
          'baselineKwhUsed': (data['baselineKwhUsed'] ?? 0.0).toDouble(),
          'lastUpdated': data['lastUpdated'],
          'alertEnabled': data['alertEnabled'] ?? true,
          'lastAlertDismissedAt':
              (data['lastAlertDismissedAt'] as Timestamp?)?.toDate(),
          'lastAlertDismissedType': data['lastAlertDismissedType'],
          'lastAlertGeneratedAt':
              (data['lastAlertGeneratedAt'] as Timestamp?)?.toDate(),
          'lastAlertGeneratedType': data['lastAlertGeneratedType'],
          'snoozedUntil': (data['snoozedUntil'] as Timestamp?)?.toDate(),
        };
      }
      return null;
    } catch (e) {
      AppLogger.e('[FirestoreBudgetService] Error getting budget: $e');
      return null;
    }
  }

  /// Stream of budget target changes
  Stream<Map<String, dynamic>?> listenToBudgetTarget() {
    return _budgetRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()! as Map<String, dynamic>;
        return {
          'totalBudget': (data['totalBudget'] ?? 0.0).toDouble(),
          'remainingBudget': (data['remainingBudget'] ?? 0.0).toDouble(),
          'ratePerKwh': (data['ratePerKwh'] ?? 12.50).toDouble(),
          'thresholdPercentage':
              (data['thresholdPercentage'] ?? 80.0).toDouble(),
          'baselineKwhUsed': (data['baselineKwhUsed'] ?? 0.0).toDouble(),
          'lastUpdated': data['lastUpdated'],
          'alertEnabled': data['alertEnabled'] ?? true,
        };
      }
      return null;
    });
  }

  /// Create or update budget target
  Future<bool> setBudgetTarget({
    required double totalBudget,
    required double ratePerKwh,
    required double thresholdPercentage,
    bool alertEnabled = true,
    double? baselineKwhUsed,
  }) async {
    if (_userId.isEmpty) {
      AppLogger.e('[FirestoreBudgetService] User not authenticated');
      return false;
    }

    try {
      final updateData = <String, dynamic>{
        'totalBudget': totalBudget,
        'remainingBudget': totalBudget, // Initialize remaining = total
        'ratePerKwh': ratePerKwh,
        'thresholdPercentage': thresholdPercentage,
        'lastUpdated': FieldValue.serverTimestamp(),
        'alertEnabled': alertEnabled,
      };

      // Add baselineKwhUsed if provided (for editing budget)
      if (baselineKwhUsed != null) {
        updateData['baselineKwhUsed'] = baselineKwhUsed;
      } else {
        // On first creation, check if baseline exists, otherwise set to 0
        final existingDoc = await _budgetRef.get();
        if (!existingDoc.exists) {
          updateData['baselineKwhUsed'] = 0.0;
        }
        // If document exists and baselineKwhUsed is not set, it will remain unchanged
      }

      updateData['createdAt'] = FieldValue.serverTimestamp();

      await _budgetRef.set(updateData, SetOptions(merge: true));

      // Also sync to Realtime Database
      await _targetThresholdRef.update({
        'target_cost': totalBudget,
        'threshold_percentage': thresholdPercentage,
      });

      AppLogger.i('[FirestoreBudgetService] Budget target set successfully');
      return true;
    } catch (e) {
      AppLogger.e('[FirestoreBudgetService] Error setting budget: $e');
      return false;
    }
  }

  /// Update remaining budget (called after calculation)
  Future<bool> updateRemainingBudget(double remainingBudget) async {
    if (_userId.isEmpty) return false;

    try {
      // Update Firestore
      await _budgetRef.update({
        'remainingBudget': remainingBudget,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Note: Remaining budget is only stored in Firestore
      // target_cost in Realtime DB represents the total budget, not remaining

      return true;
    } catch (e) {
      AppLogger.e(
        '[FirestoreBudgetService] Error updating remaining budget: $e',
      );
      return false;
    }
  }

  /// Update threshold percentage
  Future<bool> updateThresholdPercentage(double thresholdPercentage) async {
    if (_userId.isEmpty) return false;

    try {
      await _budgetRef.update({
        'thresholdPercentage': thresholdPercentage,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Also update Realtime Database
      await _targetThresholdRef
          .child('threshold_percentage')
          .set(thresholdPercentage);

      return true;
    } catch (e) {
      AppLogger.e('[FirestoreBudgetService] Error updating threshold: $e');
      return false;
    }
  }

  /// Toggle alert enabled/disabled
  Future<bool> toggleAlert(bool enabled) async {
    if (_userId.isEmpty) return false;

    try {
      await _budgetRef.update({
        'alertEnabled': enabled,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      AppLogger.e('[FirestoreBudgetService] Error toggling alert: $e');
      return false;
    }
  }

  /// Delete budget target
  Future<bool> deleteBudgetTarget() async {
    if (_userId.isEmpty) return false;

    try {
      await _budgetRef.delete();

      // Also clear Realtime Database budget fields only
      await _targetThresholdRef.child('target_cost').set(null);
      await _targetThresholdRef.child('threshold_percentage').set(null);

      AppLogger.i('[FirestoreBudgetService] Budget target deleted');
      return true;
    } catch (e) {
      AppLogger.e('[FirestoreBudgetService] Error deleting budget: $e');
      return false;
    }
  }

  Future<void> clearAlertDismissal() async {
    if (_userId.isEmpty) return;
    try {
      await _budgetRef.set({
        'lastAlertDismissedAt': null,
        'lastAlertDismissedType': null,
        'snoozedUntil': null,
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.e(
        '[FirestoreBudgetService] Error clearing alert dismissal: $e',
      );
    }
  }
}
