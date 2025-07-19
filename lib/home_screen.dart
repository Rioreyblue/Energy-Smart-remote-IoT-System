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
    const Center(child: Text('Activity')),
    const Center(child: Text('Suggestion')),
    const Center(child: Text('Profile')),
  ];

  final List<String> _labels = [
    'ENERGY SMART',
    'Activity',
    'Suggestion',
    'Profile',
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

        automaticallyImplyLeading: true,
        leading: Icon(Iconsax.radar_2),
        flexibleSpace: SafeArea(
          child: Container(
            margin: EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Insets.md),
              gradient: LinearGradient(
                colors: [AppColor.accentGreen, AppColor.lowConsumption],
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

      //body
      body: _pages[_currentIndex],

      // bottomNavigation
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.all(Insets.sm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Insets.md),
            child: AnimatedBottomNavigationBar(
              splashSpeedInMilliseconds: 400,
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

      //this
      // bottomNavigationBar: Container(
      //   color: Theme.of(context).colorScheme.surface,
      //   child: Padding(
      //     padding: EdgeInsets.all(Insets.sm),
      //     child: ClipRRect(
      //       borderRadius: BorderRadius.circular(Insets.md),
      //       child: AnimatedBottomNavigationBar.builder(
      //         itemCount: _labels.length,
      //         tabBuilder: (int index, bool isActive) {
      //           final color =
      //               isActive
      //                   ? (isDarkMode ? AppColor.surfaceDark : AppColor.surface)
      //                   : Colors.white;

      //           return Column(
      //             mainAxisAlignment: MainAxisAlignment.center,
      //             children: [
      //               Icon(
      //                 [
      //                   Iconsax.home,
      //                   Iconsax.activity,
      //                   Iconsax.airdrop,
      //                   Iconsax.setting,
      //                 ][index],
      //                 color: color,
      //               ),
      //               const SizedBox(height: 4),
      //               Text(
      //                 _labels[index],
      //                 style: TextStyle(
      //                   color: color,
      //                   fontSize: 12,
      //                   fontWeight: FontWeight.w500,
      //                 ),
      //               ),
      //             ],
      //           );
      //         },
      //         activeIndex: _currentIndex,
      //         gapLocation: GapLocation.none,
      //         onTap: (index) {
      //           setState(() {
      //             _currentIndex = index;
      //           });
      //         },
      //         backgroundGradient: LinearGradient(
      //           colors: [AppColor.accentGreen, AppColor.lowConsumption],
      //         ),
      //       ),
      //     ),
      //   ),
      // ),
    );
  }
}
