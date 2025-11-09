class AppConfig {
  AppConfig._();

  static const String appName = 'Energy Smart';
  static const String smsChefSecret =
      '82902db80dc14366ec73f29deb21cfe77640f3d7';
  static const String smsChefMode = 'devices';
  static const String smsChefSimSlot = '1';
  static const String smsChefDeviceId = '0dae8e67d43da55c';
  static const Duration smsOtpValidity = Duration(minutes: 5);
}
