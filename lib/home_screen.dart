import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'widgets/theme_switch_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    const Center(child: Text('ACIVITY')),
    const Center(child: Text('UTILITIES')),
    const Center(child: Text('PROFILE')),
  ];

  final List<String> _labels = [
    'ENERGY SMART',
    'ACIVITY',
    'UTILITIES',
    'PROFILE',
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
        automaticallyImplyLeading: false,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(
                  Iconsax.radar_2,
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppColor.accentGreen),
              child: Center(
                child: Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.storage),
              title: Text('Data Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/dataManagement');
              },
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('Bill History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/billHistory');
              },
            ),
            ListTile(
              leading: Icon(Icons.file_upload),
              title: Text('Export Usage Data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/exportUsageData');
              },
            ),
            ListTile(
              leading: Icon(Icons.tips_and_updates),
              title: Text('Tips & Advice'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/tipsAdvice');
              },
            ),
            ListTile(
              leading: Icon(Icons.help_center),
              title: Text('FAQ / Help Center'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/faqHelpCenter');
              },
            ),
            ListTile(
              leading: Icon(Icons.feedback),
              title: Text('Feedback'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/feedback');
              },
            ),
            ListTile(
              leading: Icon(Icons.contact_mail),
              title: Text('Contact Admin / Helpdesk'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/contactAdmin');
              },
            ),
          ],
        ),
      ),
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
