import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import '../components/confirm_theme_dialog.dart';

class ThemeSwitchTile extends StatelessWidget {
  const ThemeSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder:
            (child, animation) =>
                RotationTransition(turns: animation, child: child),
        child:
            isDark
                ? const Icon(
                  Icons.nightlight_round,
                  key: ValueKey('moon'),
                  color: Colors.white70,
                )
                : const Icon(
                  Icons.wb_sunny,
                  key: ValueKey('sun'),
                  color: Colors.black54,
                ),
      ),
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmThemeDialog(isDark: !isDark),
        );

        if (confirmed == true) {
          themeProvider.setDarkMode(!isDark);
        }
      },
    );
  }
}
