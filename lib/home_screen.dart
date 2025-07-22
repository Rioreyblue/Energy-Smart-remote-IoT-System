import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/pages/goals/goals_page.dart';
import 'package:exercise_app/pages/home/home_page.dart';
import 'package:exercise_app/pages/monitoring/monitoring_page.dart';
import 'package:exercise_app/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'widgets/theme_switch_button.dart';
import 'widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    MonitoringPage(),
    GoalsPage(),
    SettingsPage()
  ];

  final List<String> _labels = [
    'ENERGY SMART',
    'MONITORING',
    'GOALS',
    'SETTINGS',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      //appbar
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          children: [
            Text(
              _labels[_currentIndex],
              style: TextStyle(
                letterSpacing: 5,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: Insets.lg,
              ),
            ),
          ],
        ),
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(
                  Iconsax.sidebar_left,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Open navigation menu',
              ),
        ),
        flexibleSpace: SafeArea(
          child: Container(
            margin: EdgeInsets.all(Insets.sm - 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Insets.md),
              color: AppColor.accentGreen.withAlpha(128),
            ),
            child: Container(
              margin: EdgeInsets.all(Insets.xm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Insets.md),
                gradient: LinearGradient(
                  colors: [AppColor.accentGreen, AppColor.lowConsumption],
                ),
              ),
            ),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: Insets.md),
            child: ThemeSwitchTile(),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      //body
      body: _pages[_currentIndex],

      // bottomNavigation
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: EdgeInsets.all(Insets.xm - 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Insets.md),
            // color: Theme.of(context).colorScheme.surface,
            color: AppColor.accentGreen.withAlpha(128),
          ),
          child: Padding(
            padding: EdgeInsets.all(Insets.xm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Insets.md),
              child: AnimatedBottomNavigationBar(
                splashSpeedInMilliseconds: 500,
                icons: const [
                  Iconsax.home,
                  Iconsax.activity,
                  Iconsax.airdrop,
                  Iconsax.setting,
                ],
                gapLocation: GapLocation.none,
                activeColor:
                    (isDarkMode ? AppColor.surfaceDark : AppColor.surface),
                splashColor:
                    (isDarkMode ? AppColor.surfaceDark : AppColor.surface),
                backgroundGradient: LinearGradient(
                  colors: [AppColor.accentGreen, AppColor.lowConsumption],
                ),
                activeIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
