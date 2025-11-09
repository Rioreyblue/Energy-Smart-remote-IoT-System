import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling testing verification codes for SMS
/// This allows developers to use predefined codes for testing without sending actual SMS
class TestingVerificationService {
  static const String _testingModeKey = 'testing_mode_enabled';
  static const String _testingCodeKey = 'testing_verification_code';

  // Predefined testing codes for different scenarios
  static const Map<String, String> _testingCodes = {
    'success': '123456', // Always succeeds
    'invalid': '000000', // Always fails
    'expired': '999999', // Simulates expired code
    'rate_limit': '111111', // Simulates rate limiting
    'network_error': '222222', // Simulates network error
  };

  /// Check if testing mode is enabled
  static Future<bool> isTestingModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_testingModeKey) ?? false;
  }

  /// Enable or disable testing mode
  static Future<void> setTestingMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testingModeKey, enabled);
  }

  /// Generate a random 6-digit testing code
  static String generateRandomTestingCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Get a predefined testing code by scenario
  static String getTestingCode(String scenario) {
    return _testingCodes[scenario] ?? generateRandomTestingCode();
  }

  /// Get all available testing scenarios
  static List<String> getTestingScenarios() {
    return _testingCodes.keys.toList();
  }

  /// Validate a testing code
  static TestingCodeResult validateTestingCode(String code) {
    // Check for predefined scenarios
    for (final entry in _testingCodes.entries) {
      if (code == entry.value) {
        return _getScenarioResult(entry.key);
      }
    }

    // Check if it's a valid 6-digit number
    if (RegExp(r'^\d{6}$').hasMatch(code)) {
      return TestingCodeResult(
        isValid: true,
        message: 'Testing code accepted',
        scenario: 'custom',
      );
    }

    return TestingCodeResult(
      isValid: false,
      message: 'Invalid testing code format',
      scenario: 'invalid',
    );
  }

  /// Get result for specific testing scenario
  static TestingCodeResult _getScenarioResult(String scenario) {
    switch (scenario) {
      case 'success':
        return TestingCodeResult(
          isValid: true,
          message: 'Testing code accepted - Success scenario',
          scenario: scenario,
        );
      case 'invalid':
        return TestingCodeResult(
          isValid: false,
          message: 'Testing code rejected - Invalid scenario',
          scenario: scenario,
        );
      case 'expired':
        return TestingCodeResult(
          isValid: false,
          message: 'Testing code expired - Expired scenario',
          scenario: scenario,
        );
      case 'rate_limit':
        return TestingCodeResult(
          isValid: false,
          message: 'Too many attempts - Rate limit scenario',
          scenario: scenario,
        );
      case 'network_error':
        return TestingCodeResult(
          isValid: false,
          message: 'Network error - Network error scenario',
          scenario: scenario,
        );
      default:
        return TestingCodeResult(
          isValid: false,
          message: 'Unknown testing scenario',
          scenario: scenario,
        );
    }
  }

  /// Store a custom testing code
  static Future<void> setCustomTestingCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_testingCodeKey, code);
  }

  /// Get stored custom testing code
  static Future<String?> getCustomTestingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_testingCodeKey);
  }

  /// Clear stored custom testing code
  static Future<void> clearCustomTestingCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_testingCodeKey);
  }

  /// Get testing code instructions
  static String getTestingInstructions() {
    return '''
Testing Verification Codes:

Predefined Codes:
• 123456 - Success (always works)
• 000000 - Invalid (always fails)
• 999999 - Expired (simulates expired code)
• 111111 - Rate Limit (simulates too many attempts)
• 222222 - Network Error (simulates network issues)

Custom Codes:
• Any 6-digit number will be accepted as valid
• Use the "Set Custom Code" option to store a specific code

Instructions:
1. Enable testing mode in the verification page
2. Enter any of the predefined codes or a custom 6-digit code
3. The system will simulate the corresponding response
4. Disable testing mode when done testing
''';
  }
}

/// Result of testing code validation
class TestingCodeResult {
  final bool isValid;
  final String message;
  final String scenario;

  const TestingCodeResult({
    required this.isValid,
    required this.message,
    required this.scenario,
  });

  @override
  String toString() {
    return 'TestingCodeResult(isValid: $isValid, message: $message, scenario: $scenario)';
  }
}





