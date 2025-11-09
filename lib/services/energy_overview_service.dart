import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:rxdart/rxdart.dart';
import '../utils/app_logger.dart';

class EnergyOverviewService {
  static final EnergyOverviewService _instance =
      EnergyOverviewService._internal();
  factory EnergyOverviewService() => _instance;
  EnergyOverviewService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Database paths
  static const String _usersCollection = 'users';
  static const String _energyMetadataPath = 'energy_metadata';
  static const String _usersPath = 'users';
  static const String _appliancesPath = 'appliances';

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Check if user is authenticated
  bool get _isAuthenticated => _auth.currentUser != null;

  // Default rate per kWh (should be configurable)
  static const double _defaultRatePerKwh = 12.0;

  // Get current usage from Realtime Database
  Future<double> getCurrentUsage() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return 0.0;
    }

    try {
      final snapshot =
          await _database
              .ref('$_usersPath/$_currentUserId/$_appliancesPath')
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        double totalKwh = 0.0;

        data.forEach((key, value) {
          final applianceData = Map<String, dynamic>.from(value);
          if (applianceData['isOn'] == true) {
            final watts = (applianceData['watts'] ?? 0).toDouble();
            final startTime = applianceData['startTime'] as String?;

            if (startTime != null && startTime.isNotEmpty) {
              final start = DateTime.parse(startTime);
              final now = DateTime.now();
              final duration = now.difference(start);
              final hours = duration.inMinutes / 60.0;
              final kwh = (watts * hours) / 1000.0;
              totalKwh += kwh;
            }
          }
        });

        return totalKwh;
      }
      return 0.0;
    } catch (e) {
      AppLogger.i('[EnergyOverviewService] Error getting current usage: $e');
      return 0.0;
    }
  }

  // Get current usage stream
  Stream<double> getCurrentUsageStream() {
    if (!_isAuthenticated || _currentUserId == null) {
      return Stream.value(0.0);
    }

    return _database
        .ref('$_usersPath/$_currentUserId/$_appliancesPath')
        .onValue
        .map((event) {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            double totalKwh = 0.0;

            data.forEach((key, value) {
              final applianceData = Map<String, dynamic>.from(value);
              if (applianceData['isOn'] == true) {
                final watts = (applianceData['watts'] ?? 0).toDouble();
                final startTime = applianceData['startTime'] as String?;

                if (startTime != null && startTime.isNotEmpty) {
                  final start = DateTime.parse(startTime);
                  final now = DateTime.now();
                  final duration = now.difference(start);
                  final hours = duration.inMinutes / 60.0;
                  final kwh = (watts * hours) / 1000.0;
                  totalKwh += kwh;
                }
              }
            });

            return totalKwh;
          }
          return 0.0;
        });
  }

  // Get today's cost
  Future<double> getTodaysCost() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final doc =
          await _firestore
              .collection(_usersCollection)
              .doc(_currentUserId)
              .collection(_energyMetadataPath)
              .doc(monthId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        return (data['totalCost'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting today\'s cost: $e');
      return 0.0;
    }
  }

  // Get today's cost stream
  Stream<double> getTodaysCostStream() {
    if (!_isAuthenticated || _currentUserId == null) {
      return Stream.value(0.0);
    }

    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return _firestore
        .collection(_usersCollection)
        .doc(_currentUserId)
        .collection(_energyMetadataPath)
        .doc(monthId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return (snapshot.data()!['totalCost'] ?? 0.0).toDouble();
          }
          return 0.0;
        });
  }

  // Get target cost
  Future<double> getTargetCost() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final doc =
          await _firestore
              .collection(_usersCollection)
              .doc(_currentUserId)
              .collection(_energyMetadataPath)
              .doc(monthId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        return (data['targetCost'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      AppLogger.i('[EnergyOverviewService] Error getting target cost: $e');
      return 0.0;
    }
  }

  // Get target cost stream
  Stream<double> getTargetCostStream() {
    if (!_isAuthenticated || _currentUserId == null) {
      return Stream.value(0.0);
    }

    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return _firestore
        .collection(_usersCollection)
        .doc(_currentUserId)
        .collection(_energyMetadataPath)
        .doc(monthId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return (snapshot.data()!['targetCost'] ?? 0.0).toDouble();
          }
          return 0.0;
        });
  }

  // Get this month's consumption
  Future<double> getThisMonthConsumption() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final doc =
          await _firestore
              .collection(_usersCollection)
              .doc(_currentUserId)
              .collection(_energyMetadataPath)
              .doc(monthId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        return (data['totalConsumption'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting this month\'s consumption: $e');
      return 0.0;
    }
  }

  // Get this month's consumption stream
  Stream<double> getThisMonthConsumptionStream() {
    if (!_isAuthenticated || _currentUserId == null) {
      return Stream.value(0.0);
    }

    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return _firestore
        .collection(_usersCollection)
        .doc(_currentUserId)
        .collection(_energyMetadataPath)
        .doc(monthId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return (snapshot.data()!['totalConsumption'] ?? 0.0).toDouble();
          }
          return 0.0;
        });
  }

  // Calculate conversion value (kWh to cost)
  double calculateConversionValue(double kwh, {double? ratePerKwh}) {
    final rate = ratePerKwh ?? _defaultRatePerKwh;
    return kwh * rate;
  }

  // Format currency
  String formatCurrency(double value) {
    return '₱${value.toStringAsFixed(4)}';
  }

  // Format kWh
  String formatKwh(double value) {
    return '${value.toStringAsFixed(2)} kW';
  }

  // Check if monthly reset is needed
  Future<bool> checkMonthlyReset() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return false;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final doc =
          await _firestore
              .collection(_usersCollection)
              .doc(_currentUserId)
              .collection(_energyMetadataPath)
              .doc(monthId)
              .get();

      // If no document exists for current month, reset is needed
      return !doc.exists;
    } catch (e) {
      AppLogger.i('[EnergyOverviewService] Error checking monthly reset: $e');
      return false;
    }
  }

  // Initialize monthly data
  Future<void> initializeMonthlyData() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await _firestore
          .collection(_usersCollection)
          .doc(_currentUserId)
          .collection(_energyMetadataPath)
          .doc(monthId)
          .set({
            'totalConsumption': 0.0,
            'totalCost': 0.0,
            'targetCost': 0.0,
            'timestamp': FieldValue.serverTimestamp(),
            'deviceLogs': {},
          });
    } catch (e) {
      AppLogger.i('[EnergyOverviewService] Error initializing monthly data: $e');
    }
  }

  // Get comprehensive energy overview data
  Future<Map<String, dynamic>> getEnergyOverviewData() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return {
        'currentUsage': 0.0,
        'conversionValue': 0.0,
        'todaysCost': 0.0,
        'targetCost': 0.0,
        'thisMonth': 0.0,
      };
    }

    try {
      final currentUsage = await getCurrentUsage();
      final todaysCost = await getTodaysCost();
      final targetCost = await getTargetCost();
      final thisMonth = await getThisMonthConsumption();
      final conversionValue = calculateConversionValue(currentUsage);

      return {
        'currentUsage': currentUsage,
        'conversionValue': conversionValue,
        'todaysCost': todaysCost,
        'targetCost': targetCost,
        'thisMonth': thisMonth,
      };
    } catch (e) {
      AppLogger.i('[EnergyOverviewService] Error getting energy overview data: $e');
      return {
        'currentUsage': 0.0,
        'conversionValue': 0.0,
        'todaysCost': 0.0,
        'targetCost': 0.0,
        'thisMonth': 0.0,
      };
    }
  }

  // Get comprehensive energy overview data stream
  Stream<Map<String, dynamic>> getEnergyOverviewDataStream() {
    if (!_isAuthenticated || _currentUserId == null) {
      return Stream.value({
        'currentUsage': 0.0,
        'conversionValue': 0.0,
        'todaysCost': 0.0,
        'targetCost': 0.0,
        'thisMonth': 0.0,
      });
    }

    return Rx.combineLatest4(
      getCurrentUsageStream(),
      getTodaysCostStream(),
      getTargetCostStream(),
      getThisMonthConsumptionStream(),
      (
        double currentUsage,
        double todaysCost,
        double targetCost,
        double thisMonth,
      ) {
        final conversionValue = calculateConversionValue(currentUsage);
        return {
          'currentUsage': currentUsage,
          'conversionValue': conversionValue,
          'todaysCost': todaysCost,
          'targetCost': targetCost,
          'thisMonth': thisMonth,
        };
      },
    );
  }
}
