import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Service for managing power rates
class RatesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference get _currentRateRef =>
      _firestore.collection('admin_settings').doc('system_config');

  /// Get current power rate from admin_settings/system_config/powerRate
  Future<double> getCurrentRate() async {
    try {
      final doc = await _currentRateRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['powerRate'] != null) {
          return (data['powerRate'] as num).toDouble();
        }
      }
    } catch (e) {
      AppLogger.i('[RatesService] Error getting current rate: $e');
    }
    return 12.50; // Default rate
  }

  /// Stream of current power rate
  Stream<double> listenToCurrentRate() {
    return _currentRateRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['powerRate'] != null) {
          return (data['powerRate'] as num).toDouble();
        }
      }
      return 12.50; // Default rate
    });
  }

  /// Stream of current rate with metadata
  Stream<Map<String, dynamic>> listenToCurrentRateWithMetadata() {
    return _currentRateRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return {
          'rate_per_kwh': (data['powerRate'] ?? 12.50).toDouble(),
          'last_updated': data['updatedAt'],
          'updated_by': data['updatedBy'] ?? 'system',
          'currency': 'PHP',
          'unit': 'kWh',
        };
      }
      return {
        'rate_per_kwh': 12.50,
        'last_updated': null,
        'updated_by': 'system',
        'currency': 'PHP',
        'unit': 'kWh',
      };
    });
  }

  /// Set current power rate (admin only) - uses admin_settings/system_config/powerRate
  Future<void> setCurrentRate(double rate, {String? updatedBy}) async {
    try {
      await _currentRateRef.set({
        'powerRate': rate,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy ?? _auth.currentUser?.uid ?? 'system',
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to set current rate: $e');
    }
  }

  /// Update current power rate - uses admin_settings/system_config/powerRate
  Future<void> updateCurrentRate(double rate, {String? updatedBy}) async {
    try {
      await _currentRateRef.update({
        'powerRate': rate,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy ?? _auth.currentUser?.uid ?? 'system',
      });
    } catch (e) {
      throw Exception('Failed to update current rate: $e');
    }
  }

  /// Get rate history
  Future<List<Map<String, dynamic>>> getRateHistory({int limit = 50}) async {
    try {
      final query =
          await _firestore
              .collection('power_rates')
              .doc('history')
              .collection('rates')
              .orderBy('updated_at', descending: true)
              .limit(limit)
              .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'rate': (data['rate'] ?? 0.0).toDouble(),
          'updated_at': data['updated_at'],
          'updated_by': data['updated_by'] ?? 'system',
          'currency': data['currency'] ?? 'PHP',
          'unit': data['unit'] ?? 'kWh',
        };
      }).toList();
    } catch (e) {
      AppLogger.i('[RatesService] Error getting rate history: $e');
      return [];
    }
  }

  /// Save rate to history
  Future<void> saveRateToHistory(double rate, {String? updatedBy}) async {
    try {
      await _firestore
          .collection('power_rates')
          .doc('history')
          .collection('rates')
          .add({
            'rate': rate,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': updatedBy ?? _auth.currentUser?.uid ?? 'system',
            'currency': 'PHP',
            'unit': 'kWh',
          });
    } catch (e) {
      AppLogger.i('[RatesService] Error saving rate to history: $e');
    }
  }

  /// Calculate cost from kWh
  double calculateCost(double kwh, {double? customRate}) {
    final rate = customRate ?? 12.50;
    return kwh * rate;
  }

  /// Calculate kWh from cost
  double calculateKwh(double cost, {double? customRate}) {
    final rate = customRate ?? 12.50;
    return cost / rate;
  }

  /// Format currency
  String formatCurrency(double amount, {String currency = '₱'}) {
    return '$currency${amount.toStringAsFixed(2)}';
  }

  /// Get rate comparison with previous rate
  Future<Map<String, dynamic>> getRateComparison() async {
    try {
      final currentRate = await getCurrentRate();
      final history = await getRateHistory(limit: 2);

      if (history.length < 2) {
        return {
          'currentRate': currentRate,
          'previousRate': currentRate,
          'change': 0.0,
          'changePercentage': 0.0,
          'trend': 'stable',
        };
      }

      final previousRate = history[1]['rate'] as double;
      final change = currentRate - previousRate;
      final changePercentage = (change / previousRate * 100);

      String trend = 'stable';
      if (changePercentage > 1) {
        trend = 'increasing';
      } else if (changePercentage < -1) {
        trend = 'decreasing';
      }

      return {
        'currentRate': currentRate,
        'previousRate': previousRate,
        'change': change,
        'changePercentage': changePercentage,
        'trend': trend,
      };
    } catch (e) {
      AppLogger.i('[RatesService] Error getting rate comparison: $e');
      return {
        'currentRate': 12.50,
        'previousRate': 12.50,
        'change': 0.0,
        'changePercentage': 0.0,
        'trend': 'stable',
      };
    }
  }

  /// Get rate statistics
  Future<Map<String, dynamic>> getRateStatistics() async {
    try {
      final history = await getRateHistory(limit: 100);

      if (history.isEmpty) {
        return {
          'averageRate': 12.50,
          'minRate': 12.50,
          'maxRate': 12.50,
          'totalChanges': 0,
          'lastUpdated': null,
        };
      }

      final rates = history.map((item) => item['rate'] as double).toList();
      final averageRate = rates.reduce((a, b) => a + b) / rates.length;
      final minRate = rates.reduce((a, b) => a < b ? a : b);
      final maxRate = rates.reduce((a, b) => a > b ? a : b);

      return {
        'averageRate': averageRate,
        'minRate': minRate,
        'maxRate': maxRate,
        'totalChanges': history.length,
        'lastUpdated': history.first['updated_at'],
      };
    } catch (e) {
      AppLogger.i('[RatesService] Error getting rate statistics: $e');
      return {
        'averageRate': 12.50,
        'minRate': 12.50,
        'maxRate': 12.50,
        'totalChanges': 0,
        'lastUpdated': null,
      };
    }
  }

  /// Validate rate
  bool validateRate(double rate) {
    return rate > 0 && rate <= 100; // Reasonable range for PHP per kWh
  }

  /// Get rate suggestions based on usage
  Future<List<Map<String, dynamic>>> getRateSuggestions(
    double monthlyKwh,
  ) async {
    final suggestions = <Map<String, dynamic>>[];

    // Basic suggestions based on usage patterns
    if (monthlyKwh < 100) {
      suggestions.add({
        'rate': 10.0,
        'description': 'Low usage rate for minimal consumption',
        'savings': 'Save up to 20% on your bill',
      });
    } else if (monthlyKwh < 300) {
      suggestions.add({
        'rate': 12.0,
        'description': 'Standard residential rate',
        'savings': 'Balanced rate for moderate usage',
      });
    } else {
      suggestions.add({
        'rate': 15.0,
        'description': 'High usage rate for heavy consumption',
        'savings': 'Consider energy efficiency improvements',
      });
    }

    return suggestions;
  }
}
