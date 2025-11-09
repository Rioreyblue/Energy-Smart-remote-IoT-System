import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appliance_model.dart';
import '../utils/app_logger.dart';

/// Service for managing appliance data in Realtime Database
class ApplianceService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache database references to avoid recreating them
  DatabaseReference? _cachedUserRef;
  DatabaseReference? _cachedAppliancesRef;
  DatabaseReference? _cachedTodayUsageRef;

  DatabaseReference get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    if (_cachedUserRef == null || _cachedUserRef!.path != 'users/$uid') {
      _cachedUserRef = _database.ref('users/$uid');
    }
    return _cachedUserRef!;
  }

  DatabaseReference get _appliancesRef {
    _cachedAppliancesRef ??= _userRef.child('appliances');
    return _cachedAppliancesRef!;
  }

  DatabaseReference get _todayUsageRef {
    _cachedTodayUsageRef ??= _userRef.child('todayUsage');
    return _cachedTodayUsageRef!;
  }

  // Public getter for external access
  DatabaseReference get appliancesRef => _appliancesRef;

  /// Stream of all appliances for the current user - sorted in correct order
  Stream<List<ApplianceModel>> listenToAppliances() {
    return _appliancesRef.onValue.map((event) {
      if (event.snapshot.value == null) return <ApplianceModel>[];

      final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );
      final appliances =
          data.entries.map((entry) {
            return ApplianceModel.fromRealtimeDB(
              entry.key,
              Map<String, dynamic>.from(entry.value),
            );
          }).toList();

      // Sort appliances in correct order: appliances_001, appliances_002, appliances_003, appliances_004
      return _sortAppliances(appliances);
    });
  }

  /// Sort appliances in the correct order
  List<ApplianceModel> _sortAppliances(List<ApplianceModel> appliances) {
    // Define the desired order
    const order = [
      'appliances_001',
      'appliances_002',
      'appliances_003',
      'appliances_004',
    ];

    // Sort by the defined order
    appliances.sort((a, b) {
      final aIndex = order.indexOf(a.id);
      final bIndex = order.indexOf(b.id);

      // If both are in the order list, sort by their index
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      // If only one is in the order list, prioritize it
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // If neither is in the order list, sort alphabetically
      return a.id.compareTo(b.id);
    });

    return appliances;
  }

  /// Stream of a specific appliance
  Stream<ApplianceModel?> listenToAppliance(String applianceId) {
    return _appliancesRef.child(applianceId).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return ApplianceModel.fromRealtimeDB(applianceId, data);
    });
  }

  /// Toggle appliance on/off and update usage calculations
  Future<void> toggleAppliance(String applianceId, bool isOn) async {
    final now = DateTime.now();
    final applianceRef = _appliancesRef.child(applianceId);

    try {
      // Get current appliance data
      final snapshot = await applianceRef.get();
      if (!snapshot.exists) {
        throw Exception('Appliance not found');
      }

      final currentData = Map<String, dynamic>.from(snapshot.value as Map);
      final appliance = ApplianceModel.fromRealtimeDB(applianceId, currentData);

      if (isOn) {
        // Turning ON - set start time
        await applianceRef.update({
          'isOn': true,
          'startTime': now.toIso8601String(),
          'lastUpdated': now.toIso8601String(),
        });
      } else {
        // Turning OFF - calculate usage and update totals
        final startTime = DateTime.tryParse(appliance.startTime ?? '') ?? now;
        final durationSeconds = now.difference(startTime).inSeconds;

        // CUMULATIVE totalUsageTime - only resets monthly, not on each toggle
        final newTotalUsageTime =
            (appliance.totalUsageTime ?? 0) + durationSeconds;

        // Calculate kWh consumed during this session
        final watts = appliance.watts ?? 0;
        final hoursUsed = durationSeconds / 3600.0;
        final sessionKwh = (watts * hoursUsed) / 1000.0;
        final newTotalKwh = appliance.kwh + sessionKwh;

        // Update appliance state FIRST with cumulative values
        // This ensures the cumulative kwh is saved before any recalculation
        await applianceRef.update({
          'isOn': false,
          'totalUsageTime': newTotalUsageTime,
          'kwh': newTotalKwh,
          'lastStopTime': now.toIso8601String(),
          'lastUpdated': now.toIso8601String(),
        });

        // Verify the update completed by reading back the value
        // This ensures the database write is fully committed before proceeding
        final verifySnapshot = await applianceRef.get();
        if (verifySnapshot.exists) {
          final verifyData = Map<String, dynamic>.from(
            verifySnapshot.value as Map,
          );
          final verifyKwh = (verifyData['kwh'] ?? 0.0).toDouble();
          // If verification fails, log warning but continue (shouldn't happen)
          if ((verifyKwh - newTotalKwh).abs() > 0.001) {
            AppLogger.w(
              '[ApplianceService] Cumulative kwh update verification failed. Expected: $newTotalKwh, Got: $verifyKwh',
            );
          }
        }

        // Update today's usage totals AFTER cumulative kwh is confirmed saved
        // This recalculates from all appliances' cumulative kwh values
        await _updateTodayUsage(sessionKwh, durationSeconds);
      }
    } catch (e) {
      throw Exception('Failed to toggle appliance: $e');
    }
  }

  /// Update live elapsed time for currently ON appliances (for real-time UI)
  Future<void> updateLiveElapsed(String applianceId) async {
    final applianceRef = _appliancesRef.child(applianceId);
    final now = DateTime.now();

    try {
      final snapshot = await applianceRef.get();
      if (!snapshot.exists) return;

      final currentData = Map<String, dynamic>.from(snapshot.value as Map);
      final appliance = ApplianceModel.fromRealtimeDB(applianceId, currentData);

      if (appliance.isOn && appliance.startTime != null) {
        final startTime = DateTime.tryParse(appliance.startTime!) ?? now;
        final liveElapsed = now.difference(startTime).inSeconds;

        // Update live elapsed time (not persisted, for UI only)
        await applianceRef.update({
          'liveElapsed': liveElapsed,
          'lastUpdated': now.toIso8601String(),
        });
      }
    } catch (e) {
      AppLogger.i(
        '[ApplianceService] Error updating live elapsed for $applianceId: $e',
      );
    }
  }

  /// Update running usage for currently ON appliances
  Future<void> updateRunningUsage() async {
    final appliances = await _appliancesRef.get();
    if (appliances.value == null) return;

    final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
      appliances.value as Map,
    );
    final now = DateTime.now();

    for (final entry in data.entries) {
      final applianceData = Map<String, dynamic>.from(entry.value as Map);
      final appliance = ApplianceModel.fromRealtimeDB(entry.key, applianceData);

      if (appliance.isOn && appliance.startTime != null) {
        final startTime = DateTime.tryParse(appliance.startTime!) ?? now;
        final durationSeconds = now.difference(startTime).inSeconds;
        final watts = appliance.watts ?? 0;
        final hoursUsed = durationSeconds / 3600.0;
        final sessionKwh = (watts * hoursUsed) / 1000.0;

        // Update appliance with current session data
        await _appliancesRef.child(entry.key).update({
          'kwh': appliance.kwh + sessionKwh,
          'lastUpdated': now.toIso8601String(),
        });
      }
    }
  }

  /// Add a new appliance
  Future<void> addAppliance(ApplianceModel appliance) async {
    await _appliancesRef.child(appliance.id).set({
      'id': appliance.id,
      'name': appliance.name,
      'icon': appliance.icon,
      'isOn': false,
      'watts': appliance.watts,
      'startTime': null,
      'totalUsageTime': 0,
      'kwh': 0.0,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  /// Update appliance properties
  Future<void> updateAppliance(
    String applianceId,
    Map<String, dynamic> updates,
  ) async {
    updates['lastUpdated'] = DateTime.now().toIso8601String();
    await _appliancesRef.child(applianceId).update(updates);
  }

  /// Delete an appliance
  Future<void> deleteAppliance(String applianceId) async {
    await _appliancesRef.child(applianceId).remove();
  }

  /// Reset appliance usage data
  Future<void> resetApplianceUsage(String applianceId) async {
    await _appliancesRef.child(applianceId).update({
      'totalUsageTime': 0,
      'kwh': 0.0,
      'isOn': false,
      'startTime': null,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  /// Reset monthly usage for all appliances (called by Cloud Function or manual reset)
  Future<void> resetMonthlyUsage() async {
    final appliances = await _appliancesRef.get();
    if (appliances.value == null) return;

    final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
      appliances.value as Map,
    );
    final now = DateTime.now();

    for (final entry in data.entries) {
      await _appliancesRef.child(entry.key).update({
        'totalUsageTime': 0,
        'kwh': 0.0,
        'isOn': false,
        'startTime': null,
        'lastUpdated': now.toIso8601String(),
      });
    }

    // Reset today's usage as well
    await _todayUsageRef.set({
      'totalKwh': 0.0,
      'totalCost': 0.0,
      'totalUsageTime': 0,
      'date': now.toIso8601String().split('T')[0],
      'lastUpdated': now.toIso8601String(),
    });
  }

  /// Get today's usage summary
  Future<Map<String, dynamic>> getTodayUsage() async {
    final snapshot = await _todayUsageRef.get();
    if (!snapshot.exists) {
      return {
        'totalKwh': 0.0,
        'totalCost': 0.0,
        'totalUsageTime': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  /// Stream of today's usage
  Stream<Map<String, dynamic>> listenToTodayUsage() {
    return _todayUsageRef.onValue.map((event) {
      if (event.snapshot.value == null) {
        return {
          'totalKwh': 0.0,
          'totalCost': 0.0,
          'totalUsageTime': 0,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  /// Update today's usage totals
  /// Recalculates cost from all appliances' cumulative kWh (as requested: 1.b)
  Future<void> _updateTodayUsage(
    double additionalKwh,
    int additionalSeconds,
  ) async {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Recalculate totals from all appliances' cumulative kWh (as requested: 1.b)
    final appliances = await _appliancesRef.get();
    double totalKwh = 0.0;
    int totalUsageTime = 0;

    if (appliances.value != null) {
      final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
        appliances.value as Map,
      );
      for (final entry in data.entries) {
        final applianceData = Map<String, dynamic>.from(entry.value as Map);
        totalKwh += (applianceData['kwh'] ?? 0.0).toDouble();
        totalUsageTime += (applianceData['totalUsageTime'] ?? 0) as int;
      }
    }

    // Get current power rate and calculate cost
    final rate = await _getCurrentPowerRate();
    final totalCost = totalKwh * rate;

    // Update today's usage in Realtime DB with recalculated values
    await _todayUsageRef.set({
      'totalKwh': totalKwh,
      'totalCost': totalCost,
      'totalUsageTime': totalUsageTime,
      'date': todayKey,
      'lastUpdated': now.toIso8601String(),
    });

    AppLogger.i(
      '[ApplianceService] Updated today usage: ${totalKwh.toStringAsFixed(3)} kWh, ₱${totalCost.toStringAsFixed(2)}',
    );
  }

  /// Get current power rate from Firestore admin_settings/system_config/powerRate
  Future<double> _getCurrentPowerRate() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('admin_settings')
              .doc('system_config')
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data['powerRate'] != null) {
          return (data['powerRate'] as num).toDouble();
        }
      }
    } catch (e) {
      AppLogger.w('[ApplianceService] Error getting power rate: $e');
    }

    return 12.50; // Default rate
  }

  /// Calculate total usage for all appliances
  Future<Map<String, dynamic>> calculateTotalUsage() async {
    final appliances = await _appliancesRef.get();
    if (appliances.value == null) {
      return {'totalKwh': 0.0, 'totalUsageTime': 0, 'totalWatts': 0};
    }

    double totalKwh = 0.0;
    int totalUsageTime = 0;
    int totalWatts = 0;

    final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
      appliances.value as Map,
    );
    for (final entry in data.entries) {
      final applianceData = Map<String, dynamic>.from(entry.value as Map);
      totalKwh += (applianceData['kwh'] ?? 0.0).toDouble();
      totalUsageTime += (applianceData['totalUsageTime'] ?? 0) as int;
      totalWatts += (applianceData['watts'] ?? 0) as int;
    }

    return {
      'totalKwh': totalKwh,
      'totalUsageTime': totalUsageTime,
      'totalWatts': totalWatts,
    };
  }
}
