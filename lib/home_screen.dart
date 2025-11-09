import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/pages/goals/goals_page.dart';
import 'package:exercise_app/pages/home/home_page.dart';
import 'package:exercise_app/pages/monitoring/monitoring_page.dart';
import 'package:exercise_app/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'widgets/theme_switch_button.dart';
import 'widgets/app_drawer.dart';
import 'services/user_status_service.dart';
import 'components/suspended_account_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; 
  bool _isSuspendedDialogShown = false;

  // Cache pages to avoid recreating them
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize pages with callback for HomePage
    _pages = [
      HomePage(onNavigateToMonitoring: () => _switchToTab(1)),
      MonitoringPage(),
      GoalsPage(),
      SettingsPage(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for tab query parameter in route
    final state = GoRouterState.of(context);
    final tabParam = state.uri.queryParameters['tab'];
    if (tabParam != null) {
      final tabIndex = int.tryParse(tabParam);
      if (tabIndex != null && tabIndex >= 0 && tabIndex < 4) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentIndex != tabIndex) {
            setState(() {
              _currentIndex = tabIndex;
            });
            // Clear the query parameter after switching tab
            final uri = state.uri.replace(queryParameters: {});
            context.go(uri.toString());
          }
        });
      }
    }
  }

  // Method to switch tabs (accessible by child pages)
  void _switchToTab(int index) {
    const totalPages = 4; // Home, Monitoring, Goals, Settings
    if (index >= 0 && index < totalPages) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

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

    return Consumer<UserStatusService>(
      builder: (context, statusService, child) {
        // Check status changes and show/hide dialog accordingly
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // Show dialog if suspended and not already shown
          if (statusService.isSuspended && !_isSuspendedDialogShown) {
            _isSuspendedDialogShown = true;
            SuspendedAccountDialog.show(context).then((_) {
              // Dialog was closed (e.g., user navigated to chat or status changed)
              if (mounted) {
                _isSuspendedDialogShown = false;
              }
            });
          }
          // Hide dialog if active and currently shown
          else if (statusService.isActive && _isSuspendedDialogShown) {
            _isSuspendedDialogShown = false;
            // Close dialog by popping the navigator
            final navigator = Navigator.of(context, rootNavigator: true);
            if (navigator.canPop()) {
              navigator.pop();
            }
          }
        });

        return _buildScaffold(context, theme, isDarkMode);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ThemeData theme,
    bool isDarkMode,
  ) {
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
