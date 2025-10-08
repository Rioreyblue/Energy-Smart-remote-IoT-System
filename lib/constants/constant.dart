import 'package:flutter/material.dart';

class Insets {
  //defauilt spacing val
  static const double _base = 4;

  //spacing options
  static const double xm = _base;
  static const double sm = _base * 2;
  static const double md = _base * 3;
  static const double lg = _base * 4;
  static const double xl = _base * 5;
  static const double xxl = _base * 6;

  //all sides
  static const EdgeInsets allXm = EdgeInsets.all(xm);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);

  //horizontal

  //vertical
}

class AppColor {
  // Primary & Base Colors
  static const Color primary = Color(0xFF2C3E50); // Deep Navy Blue
  static const Color background = Color(0xFFFFFFFF); // Clean White
  static const Color surface = Color(0xFFF5F7FA); // Soft Light Gray

  // Dark mode variants
  static const Color primaryDark = Color(0xFF1A232E); // Even deeper navy
  static const Color backgroundDark = Color(0xFF181A20); // Near black
  static const Color surfaceDark = Color(0xFF23262F); // Dark gray

  // Accent & Interactive Colors
  static const Color accentGreen = Color(
    0xFF27AE60,
  ); // Energy Green (On/Active)
  static const Color accentRed = Color(0xFFE74C3C); // Alert Red (Off/Warning)
  static const Color disabled = Color(0xFFBDC3C7); // Warm Gray (Inactive)

  // Energy Usage Indicators
  static const Color lowConsumption = Color(0xFF1ABC9C); // Teal
  static const Color mediumConsumption = Color(0xFFF39C12); // Amber
  static const Color highConsumption = Color(0xFFE74C3C); // Crimson

  // Text Colors
  static const Color textPrimary = Color(0xFF2C3E50); // Dark Gray
  static const Color textSecondary = Color(0xFF7F8C8D); // Medium Gray
  static const Color textPrimaryDark = Color(0xFFF5F7FA); // Light for dark bg
  static const Color textSecondaryDark = Color(0xFFBDC3C7); // Muted for dark bg
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColor.surface,
  primaryColor: AppColor.primary,
  colorScheme: ColorScheme.light(
    primary: AppColor.primary,
    secondary: AppColor.accentGreen,
    surface: AppColor.surface,
    error: AppColor.accentRed,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColor.textPrimary),
    bodyMedium: TextStyle(color: AppColor.textSecondary),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColor.background,
    foregroundColor: AppColor.textPrimary,
    elevation: 0,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColor.surfaceDark,
  primaryColor: AppColor.primaryDark,
  colorScheme: ColorScheme.dark(
    primary: AppColor.primaryDark,
    secondary: AppColor.accentGreen,
    surface: AppColor.surfaceDark,
    error: AppColor.accentRed,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColor.textPrimaryDark),
    bodyMedium: TextStyle(color: AppColor.textSecondaryDark),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColor.backgroundDark,
    foregroundColor: AppColor.textPrimaryDark,
    elevation: 0,
  ),
);

class ResponsiveText {
  static double _scale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width / 375.0).clamp(0.85, 1.2);
  }

  static TextStyle body(BuildContext context) => TextStyle(
    fontSize: 14 * _scale(context),
    color: Theme.of(context).textTheme.bodyLarge?.color,
    fontWeight: FontWeight.w400,
  );

  static TextStyle title(BuildContext context) => TextStyle(
    fontSize: 20 * _scale(context),
    color: Theme.of(context).textTheme.bodyLarge?.color,
    fontWeight: FontWeight.bold,
  );

  static TextStyle label(BuildContext context) => TextStyle(
    fontSize: 12 * _scale(context),
    color: Theme.of(context).textTheme.bodyMedium?.color,
    fontWeight: FontWeight.w500,
  );

  static TextStyle headline(BuildContext context) => TextStyle(
    fontSize: 28 * _scale(context),
    color: Theme.of(context).textTheme.bodyLarge?.color,
    fontWeight: FontWeight.bold,
  );

  static TextStyle caption(BuildContext context) => TextStyle(
    fontSize: 10 * _scale(context),
    color: Theme.of(context).textTheme.bodyMedium?.color,
    fontWeight: FontWeight.normal,
  );

  static TextStyle stat(BuildContext context) => TextStyle(
    fontSize: 16 * _scale(context),
    color: Theme.of(context).textTheme.bodyLarge?.color,
    fontWeight: FontWeight.w600,
  );
}
