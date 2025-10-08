import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appliance_model.dart';

class ApplianceService {
  static final ApplianceService _instance = ApplianceService._internal();
  factory ApplianceService() => _instance;
  ApplianceService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Database paths
  static const String _usersPath = 'users';
  static const String _appliancesPath = 'appliances';
  static const String _energyMetadataPath = 'energy_metadata';

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Check if user is authenticated
  bool get _isAuthenticated => _auth.currentUser != null;

  // Get all appliances for current user
  Stream<List<ApplianceModel>> getAppliancesStream() {
    if (!_isAuthenticated || _currentUserId == null) {
      return Stream.value([]);
    }

    return _database
        .ref('$_usersPath/$_currentUserId/$_appliancesPath')
        .onValue
        .map((event) {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            return data.entries
                .map(
                  (entry) => ApplianceModel.fromMap(
                    entry.key as String,
                    Map<String, dynamic>.from(entry.value),
                  ),
                )
                .toList();
          }
          return <ApplianceModel>[];
        });
  }

  // Get appliances once
  Future<List<ApplianceModel>> getAppliances() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return [];
    }

    try {
      final snapshot =
          await _database
              .ref('$_usersPath/$_currentUserId/$_appliancesPath')
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return data.entries
            .map(
              (entry) => ApplianceModel.fromMap(
                entry.key as String,
                Map<String, dynamic>.from(entry.value),
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching appliances: $e');
      return [];
    }
  }

  // Toggle appliance state
  Future<bool> toggleAppliance(String applianceUid, bool isOn) async {
    if (!_isAuthenticated || _currentUserId == null) {
      return false;
    }

    try {
      final now = DateTime.now();
      final applianceRef = _database.ref(
        '$_usersPath/$_currentUserId/$_appliancesPath/$applianceUid',
      );

      if (isOn) {
        // Turn on - set start time
        await applianceRef.update({
          'isOn': true,
          'startTime': now.toIso8601String(),
        });
      } else {
        // Turn off - calculate usage and update totals
        final snapshot = await applianceRef.get();
        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          final appliance = ApplianceModel.fromMap(applianceUid, data);

          if (appliance.startTime.isNotEmpty) {
            final startTime = DateTime.parse(appliance.startTime);
            final duration = now.difference(startTime);
            final usageTime = duration.inMinutes;
            final usageKwh =
                (appliance.watts * usageTime) / (1000 * 60); // Convert to kWh

            await applianceRef.update({
              'isOn': false,
              'totalUsageTime': appliance.totalUsageTime + usageTime,
              'kWh': appliance.kWh + usageKwh,
              'startTime': '',
            });

            // Update Firestore metadata
            await _updateFirestoreMetadata(applianceUid, usageKwh, usageTime);
          } else {
            await applianceRef.update({'isOn': false});
          }
        }
      }

      return true;
    } catch (e) {
      print('Error toggling appliance: $e');
      return false;
    }
  }

  // Update appliance data
  Future<bool> updateAppliance(
    String applianceUid,
    Map<String, dynamic> updates,
  ) async {
    if (!_isAuthenticated || _currentUserId == null) {
      return false;
    }

    try {
      await _database
          .ref('$_usersPath/$_currentUserId/$_appliancesPath/$applianceUid')
          .update(updates);
      return true;
    } catch (e) {
      print('Error updating appliance: $e');
      return false;
    }
  }

  // Add new appliance
  Future<bool> addAppliance(ApplianceModel appliance) async {
    if (!_isAuthenticated || _currentUserId == null) {
      return false;
    }

    try {
      await _database
          .ref('$_usersPath/$_currentUserId/$_appliancesPath/${appliance.uid}')
          .set(appliance.toMap());
      return true;
    } catch (e) {
      print('Error adding appliance: $e');
      return false;
    }
  }

  // Remove appliance
  Future<bool> removeAppliance(String applianceUid) async {
    if (!_isAuthenticated || _currentUserId == null) {
      return false;
    }

    try {
      await _database
          .ref('$_usersPath/$_currentUserId/$_appliancesPath/$applianceUid')
          .remove();
      return true;
    } catch (e) {
      print('Error removing appliance: $e');
      return false;
    }
  }

  // Initialize default appliances for new user
  Future<void> initializeDefaultAppliances() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return;
    }

    try {
      final appliances = [
        ApplianceModel(
          uid: 'appliance_1',
          icon: 'Iconsax.lamp_1',
          isOn: false,
          kWh: 0.0,
          name: 'Light',
          startTime: '',
          totalUsageTime: 0,
          watts: 60,
        ),
        ApplianceModel(
          uid: 'appliance_2',
          icon: 'Iconsax.lamp_charge',
          isOn: false,
          kWh: 0.0,
          name: 'Outlet',
          startTime: '',
          totalUsageTime: 0,
          watts: 100,
        ),
        ApplianceModel(
          uid: 'appliance_3',
          icon: 'Iconsax.lamp',
          isOn: false,
          kWh: 0.0,
          name: 'Living Room',
          startTime: '',
          totalUsageTime: 0,
          watts: 80,
        ),
        ApplianceModel(
          uid: 'appliance_4',
          icon: 'Iconsax.coffee',
          isOn: false,
          kWh: 0.0,
          name: 'Kitchen',
          startTime: '',
          totalUsageTime: 0,
          watts: 120,
        ),
      ];

      for (final appliance in appliances) {
        await addAppliance(appliance);
      }
    } catch (e) {
      print('Error initializing default appliances: $e');
    }
  }

  // Reset monthly data
  Future<void> resetMonthlyData() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return;
    }

    try {
      final appliances = await getAppliances();
      for (final appliance in appliances) {
        await updateAppliance(appliance.uid, {
          'kWh': 0.0,
          'totalUsageTime': 0,
          'startTime': '',
        });
      }
    } catch (e) {
      print('Error resetting monthly data: $e');
    }
  }

  // Update Firestore metadata
  Future<void> _updateFirestoreMetadata(
    String deviceId,
    double kWhUsed,
    int usageTime,
  ) async {
    if (!_isAuthenticated || _currentUserId == null) {
      return;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final ratePerKwh = 12.0; // Default rate, should be configurable
      final cost = kWhUsed * ratePerKwh;

      final metadataRef = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection(_energyMetadataPath)
          .doc(monthId);

      await metadataRef.set({
        'totalConsumption': FieldValue.increment(kWhUsed),
        'totalCost': FieldValue.increment(cost),
        'timestamp': FieldValue.serverTimestamp(),
        'deviceLogs.$deviceId.usageDuration': FieldValue.increment(usageTime),
        'deviceLogs.$deviceId.kWhUsed': FieldValue.increment(kWhUsed),
        'deviceLogs.$deviceId.cost': FieldValue.increment(cost),
        'deviceLogs.$deviceId.updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating Firestore metadata: $e');
    }
  }

  // Get current month's energy metadata
  Future<EnergyMetadata?> getCurrentMonthMetadata() async {
    if (!_isAuthenticated || _currentUserId == null) {
      return null;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final doc =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection(_energyMetadataPath)
              .doc(monthId)
              .get();

      if (doc.exists) {
        return EnergyMetadata.fromMap(monthId, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error fetching current month metadata: $e');
      return null;
    }
  }

  // Get energy metadata stream
  Stream<EnergyMetadata?> getEnergyMetadataStream() {
    if (!_isAuthenticated || _currentUserId == null) {
      return Stream.value(null);
    }

    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection(_energyMetadataPath)
        .doc(monthId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return EnergyMetadata.fromMap(monthId, snapshot.data()!);
          }
          return null;
        });
  }

  // Set target cost for current month
  Future<bool> setTargetCost(double targetCost) async {
    if (!_isAuthenticated || _currentUserId == null) {
      return false;
    }

    try {
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection(_energyMetadataPath)
          .doc(monthId)
          .set({
            'targetCost': targetCost,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error setting target cost: $e');
      return false;
    }
  }
}

