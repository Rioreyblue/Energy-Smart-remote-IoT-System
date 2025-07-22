import 'package:exercise_app/pages/goals/goals_page.dart';
import 'package:exercise_app/pages/monitoring/monitoring_page.dart';
import 'package:exercise_app/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'widgets/theme_provider.dart';
import 'constants/constant.dart';
import 'home_screen.dart';
import 'pages/side_navigations/data_management_page.dart';
import 'pages/side_navigations/bill_history_page.dart';
import 'pages/side_navigations/export_usage_data_page.dart';
import 'pages/side_navigations/tips_advice_page.dart';
import 'pages/side_navigations/faq_help_center_page.dart';
import 'pages/side_navigations/feedback_page.dart';
import 'pages/side_navigations/contact_admin_page.dart';

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),

      routes: [
        //pages
        // GoRoute(
        //   path: 'monitoring',
        //   builder: (context, state) => const MonitoringPage(),
        // ),
        // GoRoute(
        //   path: 'goals',
        //   builder: (context, state) => const GoalsPage(),
        // ),
        // GoRoute(
        //   path: 'settings',
        //   builder: (context, state) => const SettingsPage(),
        // ),

        //drawer nako
        GoRoute(
          path: 'dataManagement',
          builder: (context, state) => const DataManagementPage(),
        ),
        GoRoute(
          path: 'billHistory',
          builder: (context, state) => const BillHistoryPage(),
        ),
        GoRoute(
          path: 'exportUsageData',
          builder: (context, state) => const ExportUsageDataPage(),
        ),
        GoRoute(
          path: 'tipsAdvice',
          builder: (context, state) => const TipsAdvicePage(),
        ),
        GoRoute(
          path: 'faqHelpCenter',
          builder: (context, state) => const FAQHelpCenterPage(),
        ),
        GoRoute(
          path: 'feedback',
          builder: (context, state) => const FeedbackPage(),
        ),
        GoRoute(
          path: 'contactAdmin',
          builder: (context, state) => const ContactAdminPage(),
        ),
      ],
    ),
  ],
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Energy Smart',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
