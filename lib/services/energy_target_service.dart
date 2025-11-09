import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/energy_target_model.dart';
import '../utils/app_logger.dart';

/// Service for managing energy targets and goals
class EnergyTargetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';
  DocumentReference get _targetRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('energyTarget')
      .doc('currentTarget');

  /// Get current energy target
  Future<EnergyTargetModel?> getCurrentTarget() async {
    try {
      final doc = await _targetRef.get();
      if (doc.exists) {
        return EnergyTargetModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
        );
      }
    } catch (e) {
      AppLogger.i('[EnergyTargetService] Error getting current target: $e');
    }
    return null;
  }

  /// Stream of current energy target
  Stream<EnergyTargetModel?> listenToCurrentTarget() {
    return _targetRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        return EnergyTargetModel.fromFirestore(
          snapshot.data() as Map<String, dynamic>,
        );
      }
      return null;
    });
  }

  /// Set current target with individual parameters
  Future<void> setCurrentTarget({
    required double targetCost,
    required double targetKwh,
    required double alertThreshold,
  }) async {
    try {
      await _targetRef.set({
        'target_cost': targetCost,
        'target_kwh': targetKwh,
        'alert_threshold': alertThreshold,
        'meterPrevious': 0.0,
        'meterPresent': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.i('[EnergyTargetService] Error setting current target: $e');
      rethrow;
    }
  }

  /// Save energy target
  Future<void> saveTarget(EnergyTargetModel target) async {
    try {
      await _targetRef.set({
        'target_cost': target.targetCost,
        'target_kwh': target.targetKwh,
        'alert_threshold': target.alertThreshold,
        'meterPrevious': target.meterPrevious,
        'meterPresent': target.meterPresent,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save energy target: $e');
    }
  }

  /// Update energy target
  Future<void> updateTarget(Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _targetRef.update(updates);
    } catch (e) {
      throw Exception('Failed to update energy target: $e');
    }
  }

  /// Validate and return threshold percentage
  Future<double> validateAndReturnThreshold() async {
    final target = await getCurrentTarget();
    if (target == null) return 80.0; // Default threshold

    return target.alertThreshold.clamp(10.0, 100.0);
  }

  /// Check if current usage exceeds threshold
  Future<bool> isThresholdExceeded(
    double currentCost,
    double currentKwh,
  ) async {
    final target = await getCurrentTarget();
    if (target == null) return false;

    final threshold = target.alertThreshold / 100.0;

    // Check both cost and kWh thresholds
    final costThreshold = target.targetCost * threshold;
    final kwhThreshold = target.targetKwh * threshold;

    return currentCost >= costThreshold || currentKwh >= kwhThreshold;
  }

  /// Get threshold values for display
  Future<Map<String, double>> getThresholdValues() async {
    final target = await getCurrentTarget();
    if (target == null) {
      return {
        'costThreshold': 0.0,
        'kwhThreshold': 0.0,
        'thresholdPercentage': 80.0,
      };
    }

    final threshold = target.alertThreshold / 100.0;
    return {
      'costThreshold': target.targetCost * threshold,
      'kwhThreshold': target.targetKwh * threshold,
      'thresholdPercentage': target.alertThreshold,
    };
  }

  /// Calculate progress percentage
  Future<Map<String, double>> calculateProgress(
    double currentCost,
    double currentKwh,
  ) async {
    final target = await getCurrentTarget();
    if (target == null) {
      return {'costProgress': 0.0, 'kwhProgress': 0.0, 'overallProgress': 0.0};
    }

    final costProgress = (currentCost / target.targetCost * 100).clamp(
      0.0,
      200.0,
    );
    final kwhProgress = (currentKwh / target.targetKwh * 100).clamp(0.0, 200.0);
    final overallProgress = (costProgress + kwhProgress) / 2;

    return {
      'costProgress': costProgress,
      'kwhProgress': kwhProgress,
      'overallProgress': overallProgress,
    };
  }

  /// Get energy efficiency recommendations
  Future<List<String>> getEfficiencyRecommendations() async {
    final target = await getCurrentTarget();
    if (target == null) return [];

    final recommendations = <String>[];

    // Cost-based recommendations
    if (target.targetCost < 1000) {
      recommendations.add(
        'Consider setting a higher target to encourage energy savings',
      );
    } else if (target.targetCost > 5000) {
      recommendations.add(
        'Your target is quite high. Consider reducing it for better motivation',
      );
    }

    // Threshold-based recommendations
    if (target.alertThreshold < 50) {
      recommendations.add(
        'Your alert threshold is very low. Consider increasing it to 70-80%',
      );
    } else if (target.alertThreshold > 90) {
      recommendations.add(
        'Your alert threshold is very high. Consider lowering it to get earlier warnings',
      );
    }

    // General recommendations
    recommendations.addAll([
      'Turn off appliances when not in use',
      'Use energy-efficient appliances',
      'Monitor your usage patterns regularly',
      'Set realistic daily and monthly targets',
    ]);

    return recommendations;
  }

  /// Get target history
  Future<List<EnergyTargetModel>> getTargetHistory() async {
    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('energyTarget')
              .doc('history')
              .collection('targets')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();

      return query.docs.map((doc) {
        return EnergyTargetModel.fromFirestore(doc.data());
      }).toList();
    } catch (e) {
      AppLogger.i('[EnergyTargetService] Error getting target history: $e');
      return [];
    }
  }

  /// Save target to history
  Future<void> saveTargetToHistory(EnergyTargetModel target) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('energyTarget')
          .doc('history')
          .collection('targets')
          .add({
            'target_cost': target.targetCost,
            'target_kwh': target.targetKwh,
            'alert_threshold': target.alertThreshold,
            'meterPrevious': target.meterPrevious,
            'meterPresent': target.meterPresent,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      AppLogger.i('[EnergyTargetService] Error saving target to history: $e');
    }
  }

  /// Reset target to default values
  Future<void> resetToDefault() async {
    final defaultTarget = EnergyTargetModel(
      targetCost: 2000.0,
      targetKwh: 100.0,
      alertThreshold: 80.0,
      meterPrevious: 0.0,
      meterPresent: 0.0,
    );

    await saveTarget(defaultTarget);
  }

  /// Get energy savings tips based on current target
  Future<List<String>> getSavingsTips() async {
    final target = await getCurrentTarget();
    if (target == null) return [];

    final tips = <String>[];

    if (target.targetCost > 1500) {
      tips.add('Consider using LED bulbs to reduce lighting costs');
      tips.add('Unplug devices when not in use to save on standby power');
    }

    if (target.targetKwh > 80) {
      tips.add('Use a programmable thermostat to optimize heating/cooling');
      tips.add('Wash clothes in cold water to save energy');
    }

    tips.addAll([
      'Take shorter showers to reduce water heating costs',
      'Use natural light during the day instead of artificial lighting',
      'Regularly clean and maintain appliances for optimal efficiency',
      'Consider energy-efficient appliances when replacing old ones',
    ]);

    return tips;
  }

  /// Calculate potential savings
  Future<Map<String, double>> calculatePotentialSavings() async {
    final target = await getCurrentTarget();
    if (target == null) {
      return {
        'monthlySavings': 0.0,
        'yearlySavings': 0.0,
        'percentageReduction': 0.0,
      };
    }

    // Assume 20% reduction is achievable with good practices
    const reductionPercentage = 0.20;
    final monthlySavings = target.targetCost * reductionPercentage;
    final yearlySavings = monthlySavings * 12;

    return {
      'monthlySavings': monthlySavings,
      'yearlySavings': yearlySavings,
      'percentageReduction': reductionPercentage * 100,
    };
  }
}
