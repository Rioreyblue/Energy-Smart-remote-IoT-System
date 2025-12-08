import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/scene_model.dart';
import '../models/appliance_model.dart';
import '../utils/app_logger.dart';

/// Service for managing customizable scenes and modes
class SceneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String get _userId => _auth.currentUser?.uid ?? '';
  CollectionReference get _scenesRef =>
      _firestore.collection('users').doc(_userId).collection('scenes');
  DatabaseReference get _appliancesRef =>
      _database.ref('users/$_userId/appliances');

  /// Get all user scenes
  Future<List<SceneModel>> getScenes() async {
    try {
      final query =
          await _scenesRef.orderBy('createdAt', descending: false).get();
      return query.docs.map((doc) {
        return SceneModel.fromFirestore(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      AppLogger.i('[SceneService] Error getting scenes: $e');
      return [];
    }
  }

  /// Stream of user scenes
  Stream<List<SceneModel>> listenToScenes() {
    return _scenesRef.orderBy('createdAt', descending: false).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return SceneModel.fromFirestore(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    });
  }

  /// Get a specific scene
  Future<SceneModel?> getScene(String sceneId) async {
    try {
      final doc = await _scenesRef.doc(sceneId).get();
      if (doc.exists) {
        return SceneModel.fromFirestore(
          sceneId,
          doc.data() as Map<String, dynamic>,
        );
      }
    } catch (e) {
      AppLogger.i('[SceneService] Error getting scene: $e');
    }
    return null;
  }

  /// Create a new scene
  Future<String> createScene(SceneModel scene) async {
    try {
      final docRef = await _scenesRef.add({
        'name': scene.name,
        'icon': scene.icon,
        'deviceStates': scene.deviceStates.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDefault': scene.isDefault,
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create scene: $e');
    }
  }

  /// Update an existing scene
  Future<void> updateScene(String sceneId, SceneModel scene) async {
    try {
      await _scenesRef.doc(sceneId).update({
        'name': scene.name,
        'icon': scene.icon,
        'deviceStates': scene.deviceStates.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update scene: $e');
    }
  }

  /// Delete a scene
  Future<void> deleteScene(String sceneId) async {
    try {
      await _scenesRef.doc(sceneId).delete();
    } catch (e) {
      throw Exception('Failed to delete scene: $e');
    }
  }

  /// Execute a scene (apply device states to appliances)
  Future<void> executeScene(String sceneId) async {
    AppLogger.d('[SceneService] Executing scene: $sceneId');

    try {
      final scene = await getScene(sceneId);
      if (scene == null) {
        AppLogger.e('[SceneService] Scene not found: $sceneId');
        throw Exception('Scene not found');
      }

      AppLogger.d(
        '[SceneService] Scene found: ${scene.name} with ${scene.deviceStates.length} device states',
      );

      // Get current appliances
      final appliancesSnapshot = await _appliancesRef.get();
      if (appliancesSnapshot.value == null) {
        AppLogger.e('[SceneService] No appliances found in database');
        throw Exception('No appliances found');
      }

      final Map<dynamic, dynamic> appliancesData = Map<dynamic, dynamic>.from(
        appliancesSnapshot.value as Map,
      );

      AppLogger.d(
        '[SceneService] Found ${appliancesData.length} appliances in database',
      );

      int updatedCount = 0;
      int matchedCount = 0;
      final List<String> unmatchedDevices = [];

      // Apply scene states to appliances
      for (final entry in appliancesData.entries) {
        final applianceId = entry.key as String;
        final applianceData = Map<String, dynamic>.from(entry.value as Map);
        final appliance = ApplianceModel.fromRealtimeDB(
          applianceId,
          applianceData,
        );

        // Find matching device state in scene using appliance ID
        final deviceState = _findMatchingDeviceState(scene, applianceId);

        if (deviceState != null) {
          matchedCount++;
          AppLogger.d(
            '[SceneService] Matched device: ${appliance.name} (applianceId: $applianceId)',
          );

          // Check if state needs to be updated (both isOn and value)
          final currentValue = applianceData['value'];
          final currentValueDouble =
              currentValue != null ? (currentValue as num).toDouble() : 1.0;
          // DeviceState.value is always non-null (defaults to 1.0)
          final valueNeedsUpdate =
              (currentValueDouble - deviceState.value).abs() > 0.001;
          final needsUpdate =
              appliance.isOn != deviceState.isOn || valueNeedsUpdate;

          if (needsUpdate) {
            AppLogger.d(
              '[SceneService] Updating appliance $applianceId: isOn=${deviceState.isOn}, value=${deviceState.value}',
            );
            await _updateApplianceState(
              applianceId,
              deviceState.isOn,
              deviceState.value,
            );
            updatedCount++;
          } else {
            AppLogger.d(
              '[SceneService] Appliance $applianceId already in desired state',
            );
          }
        } else {
          unmatchedDevices.add(appliance.name);
          AppLogger.w(
            '[SceneService] No matching device state found for: ${appliance.name}',
          );
        }
      }

      AppLogger.d(
        '[SceneService] Scene execution completed: $matchedCount matched, $updatedCount updated, ${unmatchedDevices.length} unmatched',
      );

      if (unmatchedDevices.isNotEmpty) {
        AppLogger.w(
          '[SceneService] Unmatched devices: ${unmatchedDevices.join(", ")}',
        );
      }
    } catch (e) {
      AppLogger.e('[SceneService] Error executing scene $sceneId: $e');
      throw Exception('Failed to execute scene: ${e.toString()}');
    }
  }

  /// Find matching device state by appliance ID
  /// Scenes now use appliance IDs (appliances_001, appliances_002, etc.) as keys
  DeviceState? _findMatchingDeviceState(SceneModel scene, String applianceId) {
    // Direct ID match - scenes use appliance IDs as keys
    if (scene.deviceStates.containsKey(applianceId)) {
      return scene.deviceStates[applianceId];
    }

    // No match found - this appliance is not part of this scene
    return null;
  }

  /// Update appliance state (both isOn and value)
  /// Note: value defaults to 1.0 if not provided (for non-dimmable devices)
  Future<void> _updateApplianceState(
    String applianceId,
    bool isOn,
    double value,
  ) async {
    final now = DateTime.now();
    final applianceRef = _appliancesRef.child(applianceId);

    try {
      // Get current appliance data
      final snapshot = await applianceRef.get();
      if (!snapshot.exists) {
        AppLogger.w('[SceneService] Appliance $applianceId does not exist');
        return;
      }

      final currentData = Map<String, dynamic>.from(snapshot.value as Map);
      final appliance = ApplianceModel.fromRealtimeDB(applianceId, currentData);

      final updates = <String, dynamic>{'lastUpdated': now.toIso8601String()};

      // Update isOn state
      if (appliance.isOn != isOn) {
        updates['isOn'] = isOn;

        if (isOn) {
          // Turning ON - set start time
          updates['startTime'] = now.toIso8601String();
          AppLogger.d('[SceneService] Turning ON appliance $applianceId');
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

          updates['totalUsageTime'] = newTotalUsageTime;
          updates['kwh'] = newTotalKwh;
          updates['lastStopTime'] = now.toIso8601String();
          AppLogger.d(
            '[SceneService] Turning OFF appliance $applianceId, session: ${sessionKwh.toStringAsFixed(3)} kWh',
          );
        }
      }

      // Update value (for dimming, speed control, etc.)
      // DeviceState.value is always non-null (defaults to 1.0)
      final currentValue = currentData['value'];
      final currentValueDouble =
          currentValue != null ? (currentValue as num).toDouble() : 1.0;
      // Use small epsilon for floating point comparison to avoid floating point precision issues
      if ((currentValueDouble - value).abs() > 0.001) {
        updates['value'] = value;
        AppLogger.d(
          '[SceneService] Updating appliance $applianceId value: $currentValueDouble -> $value',
        );
      }

      // Only update database if there are actual changes (more than just lastUpdated)
      if (updates.length > 1) {
        await applianceRef.update(updates);
        AppLogger.d(
          '[SceneService] Successfully updated appliance $applianceId with ${updates.length - 1} changes',
        );
      } else {
        AppLogger.d(
          '[SceneService] No changes needed for appliance $applianceId (already in desired state)',
        );
      }
    } catch (e) {
      AppLogger.e('[SceneService] Error updating appliance $applianceId: $e');
      rethrow;
    }
  }

  /// Initialize default scenes for new users
  Future<void> initializeDefaultScenes() async {
    try {
      // Get existing scenes
      final existingScenes = await getScenes();

      // Remove duplicate scenes by name (keep only the first occurrence)
      final seenNames = <String>{};
      final duplicatesToDelete = <String>[];

      for (final scene in existingScenes) {
        if (seenNames.contains(scene.name)) {
          duplicatesToDelete.add(scene.id);
        } else {
          seenNames.add(scene.name);
        }
      }

      // Delete duplicate scenes
      for (final sceneId in duplicatesToDelete) {
        try {
          await deleteScene(sceneId);
          AppLogger.d('[SceneService] Deleted duplicate scene: $sceneId');
        } catch (e) {
          AppLogger.w('[SceneService] Error deleting duplicate scene: $e');
        }
      }

      // Check if default scenes already exist by name
      final existingNames = existingScenes.map((s) => s.name).toSet();
      final defaultSceneNames = {
        'Home Mode',
        'Away Mode',
        'Sleep Mode',
        'Eco Mode',
      };

      // Only create scenes that don't exist
      if (existingNames.containsAll(defaultSceneNames)) {
        return; // All default scenes already exist
      }

      final defaultScenes = [
        SceneModel(
          id: 'home_mode',
          name: 'Home Mode',
          icon: 'Iconsax.home',
          deviceStates: {
            'appliances_001': const DeviceState(isOn: true, value: 1.0),
            'appliances_002': const DeviceState(isOn: true, value: 1.0),
            'appliances_003': const DeviceState(isOn: true, value: 0.8),
            'appliances_004': const DeviceState(isOn: true, value: 1.0),
          },
          isDefault: true,
        ),
        SceneModel(
          id: 'away_mode',
          name: 'Away Mode',
          icon: 'Iconsax.logout',
          deviceStates: {
            'appliances_001': const DeviceState(isOn: false),
            'appliances_002': const DeviceState(isOn: false),
            'appliances_003': const DeviceState(isOn: false),
            'appliances_004': const DeviceState(isOn: false),
          },
          isDefault: true,
        ),
        SceneModel(
          id: 'sleep_mode',
          name: 'Sleep Mode',
          icon: 'Iconsax.moon',
          deviceStates: {
            'appliances_001': const DeviceState(isOn: true, value: 0.3),
            'appliances_002': const DeviceState(isOn: false),
            'appliances_003': const DeviceState(isOn: false),
            'appliances_004': const DeviceState(isOn: false),
          },
          isDefault: true,
        ),
        SceneModel(
          id: 'eco_mode',
          name: 'Eco Mode',
          icon: 'Iconsax.tree',
          deviceStates: {
            'appliances_001': const DeviceState(isOn: true, value: 0.5),
            'appliances_002': const DeviceState(isOn: false),
            'appliances_003': const DeviceState(isOn: true, value: 0.5),
            'appliances_004': const DeviceState(isOn: false),
          },
          isDefault: true,
        ),
      ];

      // Create only scenes that don't exist
      for (final scene in defaultScenes) {
        if (!existingNames.contains(scene.name)) {
          await createScene(scene);
        } else {
          // Update existing scene if it has duplicate/incorrect values
          final existingScene = existingScenes.firstWhere(
            (s) => s.name == scene.name,
          );

          // Check if device states are different (for Sleep Mode and Eco Mode)
          if (scene.name == 'Sleep Mode' || scene.name == 'Eco Mode') {
            final statesMatch =
                scene.deviceStates.length ==
                    existingScene.deviceStates.length &&
                scene.deviceStates.entries.every((entry) {
                  final existingState = existingScene.deviceStates[entry.key];
                  return existingState?.isOn == entry.value.isOn &&
                      existingState?.value == entry.value.value;
                });

            if (!statesMatch) {
              // Update the scene with correct values
              await updateScene(existingScene.id, scene);
              AppLogger.d(
                '[SceneService] Updated ${scene.name} with correct values',
              );
            }
          }
        }
      }
    } catch (e) {
      AppLogger.i('[SceneService] Error initializing default scenes: $e');
    }
  }

  /// Get scene statistics
  Future<Map<String, dynamic>> getSceneStats() async {
    try {
      final scenes = await getScenes();
      final totalScenes = scenes.length;
      final defaultScenes = scenes.where((s) => s.isDefault).length;
      final customScenes = totalScenes - defaultScenes;

      return {
        'totalScenes': totalScenes,
        'defaultScenes': defaultScenes,
        'customScenes': customScenes,
        'lastCreated': scenes.isNotEmpty ? scenes.last.createdAt : null,
      };
    } catch (e) {
      AppLogger.i('[SceneService] Error getting scene stats: $e');
      return {
        'totalScenes': 0,
        'defaultScenes': 0,
        'customScenes': 0,
        'lastCreated': null,
      };
    }
  }

  /// Duplicate a scene
  Future<String> duplicateScene(String sceneId, String newName) async {
    try {
      final originalScene = await getScene(sceneId);
      if (originalScene == null) {
        throw Exception('Scene not found');
      }

      final duplicatedScene = originalScene.copyWith(
        id: '', // Will be generated by Firestore
        name: newName,
        isDefault: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await createScene(duplicatedScene);
    } catch (e) {
      throw Exception('Failed to duplicate scene: $e');
    }
  }

  /// Export scenes to JSON
  Future<Map<String, dynamic>> exportScenes() async {
    try {
      final scenes = await getScenes();
      return {
        'exportedAt': DateTime.now().toIso8601String(),
        'userId': _userId,
        'scenes':
            scenes
                .map(
                  (scene) => {
                    'name': scene.name,
                    'icon': scene.icon,
                    'deviceStates': scene.deviceStates.map(
                      (key, value) => MapEntry(key, value.toMap()),
                    ),
                  },
                )
                .toList(),
      };
    } catch (e) {
      throw Exception('Failed to export scenes: $e');
    }
  }

  /// Import scenes from JSON
  Future<void> importScenes(Map<String, dynamic> data) async {
    try {
      final scenesData = data['scenes'] as List<dynamic>? ?? [];

      for (final sceneData in scenesData) {
        final deviceStatesData =
            sceneData['deviceStates'] as Map<String, dynamic>? ?? {};
        final deviceStates = deviceStatesData.map(
          (key, value) => MapEntry(
            key,
            DeviceState.fromMap(Map<String, dynamic>.from(value)),
          ),
        );

        final scene = SceneModel(
          id: '',
          name: sceneData['name'] ?? 'Imported Scene',
          icon: sceneData['icon'] ?? 'Iconsax.home',
          deviceStates: deviceStates,
          isDefault: false,
        );

        await createScene(scene);
      }
    } catch (e) {
      throw Exception('Failed to import scenes: $e');
    }
  }
}
