import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsService {
  // Static instance for singleton pattern
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';
  DocumentReference get _settingsRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('settings')
      .doc('main');
  DocumentReference get _profileRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('profile')
      .doc('main');

  // Settings data (placeholder for database integration)
  Map<String, dynamic> _settings = {
    'pushNotifications': true,
    'alertThreshold': 80.0,
    'quietHoursEnabled': false,
    'quietHoursStart': '22:00',
    'quietHoursEnd': '07:00',
    'defaultRate': 12.50,
    'autoSync': true,
    'themeMode': 'system',
    'accentColor': 'green',
    'language': 'english',
    'backgroundUpdates': true,
    'cloudSync': true,
  };

  // Getters
  Map<String, dynamic> get settings => _settings;

  // Save individual setting
  Future<bool> saveSetting(String key, dynamic value) async {
    try {
      await _settingsRef.update({key: value});
      _settings[key] = value;
      return true;
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
      return false;
    }
  }

  // Get individual setting
  T getSetting<T>(String key, T defaultValue) {
    return _settings[key] as T? ?? defaultValue;
  }

  // Save multiple settings
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      // TODO: Replace with actual Firestore operation
      // await FirebaseFirestore.instance
      //     .collection('user_settings')
      //     .doc('settings')
      //     .set(settings, SetOptions(merge: true));

      // For now, update local state
      _settings.addAll(settings);
      return true;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  // Load all settings
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final doc = await _settingsRef.get();
      if (doc.exists) {
        _settings = Map<String, dynamic>.from(
          doc.data() as Map<String, dynamic>,
        );
      } else {
        // Create default settings if none exist
        await _settingsRef.set(_settings);
      }
      return _settings;
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return _settings;
    }
  }

  // Reset settings to default
  Future<bool> resetSettings() async {
    try {
      // TODO: Replace with actual Firestore operation
      // await FirebaseFirestore.instance
      //     .collection('user_settings')
      //     .doc('settings')
      //     .delete();

      // Reset to default values
      _settings = {
        'pushNotifications': true,
        'alertThreshold': 80.0,
        'quietHoursEnabled': false,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '07:00',
        'defaultRate': 12.50,
        'autoSync': true,
        'themeMode': 'system',
        'accentColor': 'green',
        'language': 'english',
        'backgroundUpdates': true,
        'cloudSync': true,
      };
      return true;
    } catch (e) {
      debugPrint('Error resetting settings: $e');
      return false;
    }
  }

  // Export settings data
  Map<String, dynamic> exportSettings() {
    return Map<String, dynamic>.from(_settings);
  }

  // Import settings data
  Future<bool> importSettings(Map<String, dynamic> settings) async {
    try {
      // Validate settings data
      if (settings.isEmpty) return false;

      // TODO: Replace with actual Firestore operation
      // await FirebaseFirestore.instance
      //     .collection('user_settings')
      //     .doc('settings')
      //     .set(settings);

      // For now, update local state
      _settings = Map<String, dynamic>.from(settings);
      return true;
    } catch (e) {
      debugPrint('Error importing settings: $e');
      return false;
    }
  }

  // Clear user data
  Future<bool> clearUserData() async {
    try {
      // TODO: Implement data clearing
      // await FirebaseFirestore.instance
      //     .collection('meter_readings')
      //     .where('userId', isEqualTo: currentUserId)
      //     .get()
      //     .then((snapshot) {
      //       for (DocumentSnapshot doc in snapshot.docs) {
      //         doc.reference.delete();
      //       }
      //     });

      return true;
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      return false;
    }
  }

  // Get theme mode
  String getThemeMode() {
    return getSetting<String>('themeMode', 'system');
  }

  // Set theme mode
  Future<bool> setThemeMode(String mode) async {
    return await saveSetting('themeMode', mode);
  }

  // Get accent color
  String getAccentColor() {
    return getSetting<String>('accentColor', 'green');
  }

  // Set accent color
  Future<bool> setAccentColor(String color) async {
    return await saveSetting('accentColor', color);
  }

  // Get language
  String getLanguage() {
    return getSetting<String>('language', 'english');
  }

  // Set language
  Future<bool> setLanguage(String language) async {
    return await saveSetting('language', language);
  }

  // Get notification settings
  bool getPushNotifications() {
    return getSetting<bool>('pushNotifications', true);
  }

  // Set push notifications
  Future<bool> setPushNotifications(bool enabled) async {
    return await saveSetting('pushNotifications', enabled);
  }

  // Get alert threshold
  double getAlertThreshold() {
    return getSetting<double>('alertThreshold', 80.0);
  }

  // Set alert threshold
  Future<bool> setAlertThreshold(double threshold) async {
    return await saveSetting('alertThreshold', threshold);
  }

  // Get quiet hours settings
  bool getQuietHoursEnabled() {
    return getSetting<bool>('quietHoursEnabled', false);
  }

  // Set quiet hours
  Future<bool> setQuietHours(bool enabled, {String? start, String? end}) async {
    final settings = <String, dynamic>{'quietHoursEnabled': enabled};

    if (start != null) settings['quietHoursStart'] = start;
    if (end != null) settings['quietHoursEnd'] = end;

    return await saveSettings(settings);
  }

  // Get default rate
  double getDefaultRate() {
    return getSetting<double>('defaultRate', 12.50);
  }

  // Set default rate
  Future<bool> setDefaultRate(double rate) async {
    return await saveSetting('defaultRate', rate);
  }

  // Get auto sync setting
  bool getAutoSync() {
    return getSetting<bool>('autoSync', true);
  }

  // Set auto sync
  Future<bool> setAutoSync(bool enabled) async {
    return await saveSetting('autoSync', enabled);
  }

  // Get cloud sync setting
  bool getCloudSync() {
    return getSetting<bool>('cloudSync', true);
  }

  // Set cloud sync
  Future<bool> setCloudSync(bool enabled) async {
    return await saveSetting('cloudSync', enabled);
  }

  // Get background updates setting
  bool getBackgroundUpdates() {
    return getSetting<bool>('backgroundUpdates', true);
  }

  // Set background updates
  Future<bool> setBackgroundUpdates(bool enabled) async {
    return await saveSetting('backgroundUpdates', enabled);
  }

  // Profile management methods
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final doc = await _profileRef.get();
      if (doc.exists) {
        return Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      await _profileRef.set(profileData, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return false;
    }
  }

  Future<bool> createUserProfile(Map<String, dynamic> profileData) async {
    try {
      await _profileRef.set({
        ...profileData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      return false;
    }
  }
}
