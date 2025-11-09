import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/predictive_data_model.dart';
import '../models/prediction_result_model.dart';
import '../utils/monitoring_prediction_utils.dart';
import '../utils/app_logger.dart';
import '../services/power_rate_service.dart';

/// Service for generating predictions and managing Firestore integration
class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService() => _instance;
  PredictionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// Generate prediction from dataset
  Future<PredictionResultModel?> generatePrediction({
    required List<PredictiveDataModel> dataset,
    double minRate = 10.0,
    double maxRate = 14.0,
    bool saveToFirestore = true,
  }) async {
    if (dataset.isEmpty) {
      AppLogger.w(
        '[PredictionService] Cannot generate prediction: empty dataset',
      );
      return null;
    }

    try {
      // Get current power rate from PowerRateService
      final powerRateService = PowerRateService();
      final currentPowerRate = powerRateService.currentRate;

      AppLogger.i(
        '[PredictionService] Using power rate: $currentPowerRate for prediction',
      );

      // Generate prediction using MonitoringPrediction with current power rate
      final prediction = MonitoringPrediction.predictNextMonth(
        dataset: dataset,
        minRate: minRate,
        maxRate: maxRate,
        powerRate: currentPowerRate,
      );

      // Save to Firestore if requested and user is authenticated
      if (saveToFirestore && _userId != null) {
        await savePrediction(prediction);
      }

      AppLogger.i(
        '[PredictionService] Prediction generated: ${prediction.predictedKwh.toStringAsFixed(2)} kWh, ₱${prediction.predictedCost.toStringAsFixed(2)}, Confidence: ${prediction.confidence.toStringAsFixed(1)}%',
      );

      // Log appliance cost breakdown
      if (prediction.applianceCostBreakdown != null &&
          prediction.applianceCostBreakdown!.isNotEmpty) {
        final mostCostly = prediction.getMostCostlyApplianceDetails();
        final leastCostly = prediction.getLeastCostlyApplianceDetails();
        if (mostCostly != null) {
          AppLogger.i(
            '[PredictionService] Most costly appliance: ${mostCostly['appliance']} - ₱${(mostCostly['cost'] as double).toStringAsFixed(2)} (${(mostCostly['percentage'] as double).toStringAsFixed(1)}%)',
          );
        }
        if (leastCostly != null) {
          AppLogger.i(
            '[PredictionService] Least costly appliance: ${leastCostly['appliance']} - ₱${(leastCostly['cost'] as double).toStringAsFixed(2)} (${(leastCostly['percentage'] as double).toStringAsFixed(1)}%)',
          );
        }
      }

      return prediction;
    } catch (e) {
      AppLogger.e('[PredictionService] Error generating prediction: $e');
      return null;
    }
  }

  /// Save prediction to Firestore
  Future<bool> savePrediction(PredictionResultModel prediction) async {
    if (_userId == null) {
      AppLogger.w(
        '[PredictionService] Cannot save prediction: user not authenticated',
      );
      return false;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('predictions')
          .doc(prediction.id)
          .set(prediction.toFirestore(), SetOptions(merge: true));

      AppLogger.i(
        '[PredictionService] Prediction saved to Firestore: ${prediction.id}',
      );
      return true;
    } catch (e) {
      AppLogger.e(
        '[PredictionService] Error saving prediction to Firestore: $e',
      );
      return false;
    }
  }

  /// Get predictions from Firestore
  Future<List<PredictionResultModel>> getPredictions({
    int limit = 50,
    String? month,
  }) async {
    if (_userId == null) {
      AppLogger.w(
        '[PredictionService] Cannot get predictions: user not authenticated',
      );
      return [];
    }

    try {
      Query query = _firestore
          .collection('users')
          .doc(_userId!)
          .collection('predictions')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (month != null) {
        query = query.where('month', isEqualTo: month);
      }

      final snapshot = await query.get();
      final predictions =
          snapshot.docs
              .map(
                (doc) => PredictionResultModel.fromFirestore(
                  doc.id,
                  Map<String, dynamic>.from(doc.data() as Map),
                ),
              )
              .toList();

      AppLogger.i(
        '[PredictionService] Retrieved ${predictions.length} predictions from Firestore',
      );
      return predictions;
    } catch (e) {
      AppLogger.e(
        '[PredictionService] Error getting predictions from Firestore: $e',
      );
      return [];
    }
  }

  /// Get latest prediction
  Future<PredictionResultModel?> getLatestPrediction() async {
    if (_userId == null) return null;

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(_userId!)
              .collection('predictions')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return PredictionResultModel.fromFirestore(
        doc.id,
        Map<String, dynamic>.from(doc.data() as Map),
      );
    } catch (e) {
      AppLogger.e('[PredictionService] Error getting latest prediction: $e');
      return null;
    }
  }

  /// Delete prediction from Firestore
  Future<bool> deletePrediction(String predictionId) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('predictions')
          .doc(predictionId)
          .delete();

      AppLogger.i('[PredictionService] Prediction deleted: $predictionId');
      return true;
    } catch (e) {
      AppLogger.e('[PredictionService] Error deleting prediction: $e');
      return false;
    }
  }

  /// Stream predictions from Firestore
  Stream<List<PredictionResultModel>> streamPredictions({int limit = 50}) {
    if (_userId == null) {
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('users')
          .doc(_userId!)
          .collection('predictions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => PredictionResultModel.fromFirestore(
                        doc.id,
                        Map<String, dynamic>.from(doc.data() as Map),
                      ),
                    )
                    .toList(),
          );
    } catch (e) {
      AppLogger.e('[PredictionService] Error streaming predictions: $e');
      return Stream.value([]);
    }
  }

  /// Get prediction statistics
  Future<Map<String, dynamic>> getPredictionStats() async {
    if (_userId == null) {
      return {
        'totalPredictions': 0,
        'avgConfidence': 0.0,
        'avgPredictedKwh': 0.0,
        'avgPredictedCost': 0.0,
      };
    }

    try {
      final predictions = await getPredictions(limit: 100);

      if (predictions.isEmpty) {
        return {
          'totalPredictions': 0,
          'avgConfidence': 0.0,
          'avgPredictedKwh': 0.0,
          'avgPredictedCost': 0.0,
        };
      }

      final totalPredictions = predictions.length;
      final avgConfidence =
          predictions.map((p) => p.confidence).reduce((a, b) => a + b) /
          totalPredictions;
      final avgPredictedKwh =
          predictions.map((p) => p.predictedKwh).reduce((a, b) => a + b) /
          totalPredictions;
      final avgPredictedCost =
          predictions.map((p) => p.predictedCost).reduce((a, b) => a + b) /
          totalPredictions;

      return {
        'totalPredictions': totalPredictions,
        'avgConfidence': avgConfidence,
        'avgPredictedKwh': avgPredictedKwh,
        'avgPredictedCost': avgPredictedCost,
      };
    } catch (e) {
      AppLogger.e('[PredictionService] Error getting prediction stats: $e');
      return {
        'totalPredictions': 0,
        'avgConfidence': 0.0,
        'avgPredictedKwh': 0.0,
        'avgPredictedCost': 0.0,
      };
    }
  }
}
