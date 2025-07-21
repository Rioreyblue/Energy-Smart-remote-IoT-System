import 'package:exercise_app/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:provider/provider.dart';
import 'widgets/theme_provider.dart';
import 'pages/data_management_page.dart';
import 'pages/bill_history_page.dart';
import 'pages/export_usage_data_page.dart';
import 'pages/tips_advice_page.dart';
import 'pages/faq_help_center_page.dart';
import 'pages/feedback_page.dart';
import 'pages/contact_admin_page.dart';

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
          return MaterialApp(
            title: 'Energy Smart',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            home: HomeScreen(),
            routes: {
              '/dataManagement': (context) => const DataManagementPage(),
              '/billHistory': (context) => const BillHistoryPage(),
              '/exportUsageData': (context) => const ExportUsageDataPage(),
              '/tipsAdvice': (context) => const TipsAdvicePage(),
              '/faqHelpCenter': (context) => const FAQHelpCenterPage(),
              '/feedback': (context) => const FeedbackPage(),
              '/contactAdmin': (context) => const ContactAdminPage(),
            },
          );
        },
      ),
    );
  }
}
