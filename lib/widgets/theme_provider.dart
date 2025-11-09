import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'themeMode';
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // Keep for backward compatibility
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeKey);

    if (themeModeString != null) {
      switch (themeModeString) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    } else {
      // Migrate from old boolean format
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      await prefs.setString(_themeKey, isDarkMode ? 'dark' : 'light');
      await prefs.remove('isDarkMode');
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  // Backward compatibility method
  Future<void> setDarkMode(bool value) async {
    await setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}
