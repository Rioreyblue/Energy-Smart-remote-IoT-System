/// OneSignal configuration
///
/// IMPORTANT: This file contains sensitive API keys.
/// Do NOT commit this file to version control if it contains production keys.
/// Consider using environment variables or secure storage for production.
class OneSignalConfig {
  /// OneSignal App ID
  static const String appId = '741790af-bbf1-4480-9c92-18352b884ea3';

  /// OneSignal REST API Key
  /// This is used to send push notifications via OneSignal REST API
  ///
  /// For production, use --dart-define=ONESIGNAL_REST_API_KEY=your_key
  /// when building the app, or store it securely.
  static const String restApiKey = String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
    defaultValue: 'm43csqdcaulf4m3xigbvnnujd', // Fallback for development
  );

  /// App name for reference
  static const String appName = 'Energy Smart';
}
