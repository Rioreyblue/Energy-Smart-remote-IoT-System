import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';
import '../models/goals_model.dart';

/// Service for managing local data storage
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService _instance = LocalStorageService._();
  factory LocalStorageService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user-specific storage directory
  Future<Directory> _getUserStorageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final userId = _auth.currentUser?.uid ?? 'anonymous';
    final userDir = Directory('${appDir.path}/user_data/$userId');

    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }

    return userDir;
  }

  /// Save meter readings to local storage
  Future<bool> saveMeterReadings(List<MeterReadingModel> readings) async {
    try {
      final userDir = await _getUserStorageDirectory();
      final file = File('${userDir.path}/meter_readings.json');

      final data =
          readings.map((r) {
            final map = r.toMap();
            map['id'] = r.id; // Include id in the saved data
            // Convert Timestamp to ISO string for JSON storage
            if (map['startDate'] != null) {
              map['startDate'] = r.startDate.toIso8601String();
            }
            if (map['endDate'] != null) {
              map['endDate'] = r.endDate.toIso8601String();
            }
            if (map['createdAt'] != null) {
              map['createdAt'] = r.createdAt.toIso8601String();
            }
            return map;
          }).toList();
      await file.writeAsString(jsonEncode(data));

      AppLogger.i(
        '[LocalStorageService] Saved ${readings.length} meter readings',
      );
      return true;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error saving meter readings: $e');
      return false;
    }
  }

  /// Load meter readings from local storage
  Future<List<MeterReadingModel>> loadMeterReadings() async {
    try {
      final userDir = await _getUserStorageDirectory();
      final file = File('${userDir.path}/meter_readings.json');

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);
      final readings = <MeterReadingModel>[];

      for (final item in data) {
        final map = Map<String, dynamic>.from(item);
        // MeterReadingModel.fromMap requires an id parameter
        final id =
            map['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();

        // Handle date parsing - convert from ISO string to DateTime
        if (map['startDate'] is String) {
          map['startDate'] = DateTime.parse(map['startDate']);
        }
        if (map['endDate'] is String) {
          map['endDate'] = DateTime.parse(map['endDate']);
        }
        if (map['createdAt'] is String) {
          map['createdAt'] = DateTime.parse(map['createdAt']);
        }

        // Create MeterReadingModel from map
        readings.add(
          MeterReadingModel(
            id: id,
            ratePerKwh: (map['ratePerKwh'] ?? 0.0).toDouble(),
            previousReading: (map['previousReading'] ?? 0.0).toDouble(),
            presentReading: (map['presentReading'] ?? 0.0).toDouble(),
            startDate: map['startDate'] as DateTime,
            endDate: map['endDate'] as DateTime,
            consumption: (map['consumption'] ?? 0.0).toDouble(),
            estimatedBill: (map['estimatedBill'] ?? 0.0).toDouble(),
            createdAt: map['createdAt'] as DateTime,
          ),
        );
      }

      AppLogger.i(
        '[LocalStorageService] Loaded ${readings.length} meter readings',
      );
      return readings;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error loading meter readings: $e');
      return [];
    }
  }

  /// Save user profile to local storage
  Future<bool> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(profile));
      AppLogger.i('[LocalStorageService] Saved user profile');
      return true;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error saving user profile: $e');
      return false;
    }
  }

  /// Load user profile from local storage
  Future<Map<String, dynamic>?> loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');

      if (profileJson == null) {
        return null;
      }

      final profile = jsonDecode(profileJson) as Map<String, dynamic>;
      AppLogger.i('[LocalStorageService] Loaded user profile');
      return profile;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error loading user profile: $e');
      return null;
    }
  }

  /// Save appliance data to local storage
  Future<bool> saveAppliances(List<Map<String, dynamic>> appliances) async {
    try {
      final userDir = await _getUserStorageDirectory();
      final file = File('${userDir.path}/appliances.json');
      await file.writeAsString(jsonEncode(appliances));
      AppLogger.i(
        '[LocalStorageService] Saved ${appliances.length} appliances',
      );
      return true;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error saving appliances: $e');
      return false;
    }
  }

  /// Load appliance data from local storage
  Future<List<Map<String, dynamic>>> loadAppliances() async {
    try {
      final userDir = await _getUserStorageDirectory();
      final file = File('${userDir.path}/appliances.json');

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);
      final appliances =
          data.map((item) => Map<String, dynamic>.from(item)).toList();

      AppLogger.i(
        '[LocalStorageService] Loaded ${appliances.length} appliances',
      );
      return appliances;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error loading appliances: $e');
      return [];
    }
  }

  /// Get total storage size used by local data
  Future<Map<String, int>> getStorageSize() async {
    try {
      final userDir = await _getUserStorageDirectory();
      int totalSize = 0;
      final Map<String, int> sizes = {};

      if (await userDir.exists()) {
        await for (final entity in userDir.list(recursive: true)) {
          if (entity is File) {
            final size = await entity.length();
            totalSize += size;

            final fileName = entity.path.split('/').last;
            sizes[fileName] = size;
          }
        }
      }

      // Add SharedPreferences size estimate (hard to calculate accurately)
      sizes['SharedPreferences'] = 0;

      sizes['Total'] = totalSize;
      return sizes;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error calculating storage size: $e');
      return {};
    }
  }

  /// Clear all local storage data
  Future<bool> clearLocalStorage() async {
    try {
      final userDir = await _getUserStorageDirectory();

      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');

      AppLogger.i('[LocalStorageService] Cleared local storage');
      return true;
    } catch (e) {
      AppLogger.e('[LocalStorageService] Error clearing local storage: $e');
      return false;
    }
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
