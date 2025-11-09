import 'package:exercise_app/pages/auth/login_page.dart';
import 'package:exercise_app/pages/auth/register_page.dart';
import 'package:exercise_app/pages/onboarding/onboarding_page.dart';
import 'package:exercise_app/pages/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async' show unawaited;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kDebugMode;
import 'widgets/theme_provider.dart';
import 'constants/constant.dart';
import 'firebase_options.dart';
import 'utils/app_logger.dart';
import 'utils/app_check_helper.dart';
import 'pages/auth/auth_wrapper.dart';
import 'pages/auth/phone_entry_page.dart';
import 'home_screen.dart';
import 'pages/legal/terms_privacy_page.dart';
import 'pages/side_navigations/data_management_page.dart';
import 'pages/side_navigations/bill_history_page.dart';
import 'pages/side_navigations/export_usage_data_page.dart';
import 'pages/side_navigations/tips_advice_page.dart';
import 'pages/side_navigations/faq_help_center_page.dart';
import 'pages/side_navigations/feedback_page.dart';
import 'pages/side_navigations/contact_admin_page.dart';
import 'pages/chat/support_chat_page.dart';
import 'controllers/home_controller.dart';
import 'controllers/energy_dashboard_controller.dart';
import 'controllers/budget_controller.dart';
import 'services/verification_service.dart';
import 'services/phone_auth_service.dart';
import 'services/profile_service.dart';
import 'services/chat_service.dart';
import 'services/push_notification_manager.dart';
import 'controllers/chat_notification_controller.dart';
import 'utils/app_router.dart';
import 'services/user_status_service.dart';

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthWrapper(),
        redirect: (context, state) {
          // This redirect is handled by AuthWrapper's StreamBuilder
          // Return null to allow the route to proceed
          return null;
        },
        routes: [
          GoRoute(
            path: 'home',
            builder: (context, state) => const HomeScreen(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              // If not authenticated, redirect to root (login)
              if (auth.currentUser == null) {
                return '/';
              }
              return null; // Allow route to proceed
            },
          ),
          GoRoute(
            path: 'login',
            builder: (context, state) => const NewLoginPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              // If authenticated and verified, redirect to home
              if (auth.currentUser != null) {
                return '/home';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'register',
            builder: (context, state) => const NewRegisterPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              // If authenticated and verified, redirect to home
              if (auth.currentUser != null) {
                return '/home';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'onboarding',
            builder: (context, state) => const OnboardingPage(),
          ),
          GoRoute(
            path: 'sms',
            builder: (context, state) => const PhoneEntryPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'terms',
            builder: (context, state) => const TermsPrivacyPage(),
          ),

          //drawer nako
          GoRoute(
            path: 'dataManagement',
            builder: (context, state) => const DataManagementPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'billHistory',
            builder: (context, state) => const BillHistoryPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'exportUsageData',
            builder: (context, state) => const ExportUsageDataPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'tipsAdvice',
            builder: (context, state) => const TipsAdvicePage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'faqHelpCenter',
            builder: (context, state) => const FAQHelpCenterPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'feedback',
            builder: (context, state) => const FeedbackPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'contactAdmin',
            builder: (context, state) => const ContactAdminPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
          GoRoute(
            path: 'supportChat',
            builder: (context, state) => const SupportChatPage(),
            redirect: (context, state) {
              final auth = FirebaseAuth.instance;
              if (auth.currentUser == null) {
                return '/';
              }
              return null;
            },
          ),
        ],
      ),
    ],
  );
}

/// Initialize Firebase services with security and configuration
///
/// This function:
/// 1. Initializes Firebase Core
/// 2. Sets Firebase Auth language code to prevent locale warnings
/// 3. Initializes Firebase App Check for Android (PlayIntegrity) - free tier compatible
/// 4. Initializes Firebase App Check for iOS (DeviceCheck/AppAttest) - free tier compatible
///
/// All configurations are free-tier compatible and do not require billing.
Future<void> _initializeFirebase() async {
  // Step 1: Initialize Firebase Core
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.i('[Firebase] ✅ Firebase Core initialized');

  // Step 2: Set Firebase Auth language code to prevent "X-Firebase-Locale" warning
  // This eliminates the warning: "Ignoring header X-Firebase-Locale because its value was null"
  await FirebaseAuth.instance.setLanguageCode('en');
  AppLogger.i('[Firebase] ✅ Auth language code set to English');

  // Step 3: Initialize Firebase App Check for security without billing requirements
  // This eliminates the warning: "No AppCheckProvider installed"
  // Uses platform-specific providers that are free:
  // - Android: Debug mode for development (avoids throttling), PlayIntegrity for production
  // - iOS: Debug mode for development, DeviceCheck/AppAttest for production
  try {
    final appCheck = FirebaseAppCheck.instance;

    // Log debug mode status for troubleshooting
    AppLogger.i('[Firebase] 🔍 Debug mode check: kDebugMode = $kDebugMode');

    // Platform-specific initialization
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (kDebugMode) {
        // Development: Use debug provider to avoid throttling
        AppLogger.i('[Firebase] 🔧 Activating Android Debug Provider...');
        await appCheck.activate(androidProvider: AndroidProvider.debug);
        AppLogger.i('[Firebase] ✅ App Check initialized (Android: Debug Mode)');
        // Best-effort: warm up and log token once for visibility
        // (Actual validation happens on-demand via AppCheckHelper)
        // Do not block startup if this fails
        unawaited(AppCheckHelper.logTokenOnce());
        AppLogger.i(
          '[Firebase] 📱 IMPORTANT: Check Android Logcat for debug token!',
        );
        AppLogger.i(
          '[Firebase] 📱 Look for: "AppCheck debug token:" in logcat output',
        );
        AppLogger.i(
          '[Firebase] 📱 Or filter logcat by: "AppCheck" or "Firebase"',
        );

        // Try to get the debug token after a delay
        // Note: Debug token is automatically logged to logcat by Firebase SDK
        // This is just an additional attempt to log it in Flutter logs
        try {
          await Future.delayed(const Duration(seconds: 2));
          final token = await appCheck.getToken();
          if (token != null) {
            AppLogger.i('[Firebase] 🔑 App Check Token Retrieved: $token');
            AppLogger.i(
              '[Firebase] 📋 Note: For debug tokens, check Android Logcat!',
            );
            AppLogger.i(
              '[Firebase] 📋 The debug token appears in logcat as: "AppCheck debug token: <token>"',
            );
          } else {
            AppLogger.w(
              '[Firebase] ⚠️ Token is null. Check Android Logcat for debug token.',
            );
          }
        } catch (tokenError) {
          AppLogger.w(
            '[Firebase] ⚠️ Could not retrieve token via getToken(): $tokenError',
          );
          AppLogger.w(
            '[Firebase] 📱 This is normal - check Android Logcat for the debug token instead',
          );
        }

        // Additional instructions
        AppLogger.i('[Firebase] 📋 To find debug token:');
        AppLogger.i('[Firebase] 📋 1. Open Android Studio Logcat');
        AppLogger.i('[Firebase] 📋 2. Filter by: "AppCheck" or "Firebase"');
        AppLogger.i(
          '[Firebase] 📋 3. Look for line containing "AppCheck debug token:"',
        );
        AppLogger.i('[Firebase] 📋 4. Copy the token after the colon');
      } else {
        // Production: Use PlayIntegrityProvider (free tier, no billing required)
        AppLogger.i(
          '[Firebase] 🔧 Activating Android PlayIntegrity Provider...',
        );
        await appCheck.activate(androidProvider: AndroidProvider.playIntegrity);
        AppLogger.i(
          '[Firebase] ✅ App Check initialized (Android: PlayIntegrity)',
        );
        AppLogger.i(
          '[Firebase] ℹ️ Running in production mode - PlayIntegrity active',
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (kDebugMode) {
        // Development: Use debug provider
        AppLogger.i('[Firebase] 🔧 Activating iOS Debug Provider...');
        await appCheck.activate(appleProvider: AppleProvider.debug);
        AppLogger.i('[Firebase] ✅ App Check initialized (iOS: Debug Mode)');

        // Best-effort logging for iOS debug token
        unawaited(AppCheckHelper.logTokenOnce());

        // Try to get the debug token
        try {
          await Future.delayed(const Duration(seconds: 2));
          final token = await appCheck.getToken();
          if (token != null) {
            AppLogger.i('[Firebase] 🔑 App Check Debug Token: $token');
            AppLogger.i(
              '[Firebase] 📋 Register this token in Firebase Console > App Check > Apps > [Your App] > Debug tokens',
            );
          } else {
            AppLogger.w(
              '[Firebase] ⚠️ Debug token is null. Check Xcode console for debug token.',
            );
          }
        } catch (tokenError) {
          AppLogger.w(
            '[Firebase] ⚠️ Could not retrieve debug token: $tokenError',
          );
        }
      } else {
        // Production: Use DeviceCheckProvider (free tier, no billing required)
        await appCheck.activate(appleProvider: AppleProvider.deviceCheck);
        AppLogger.i('[Firebase] ✅ App Check initialized (iOS: DeviceCheck)');
      }
    } else {
      // Web/Other platforms: Skip App Check initialization
      AppLogger.w(
        '[Firebase] ⚠️ App Check skipped for platform: $defaultTargetPlatform',
      );
    }
  } catch (e) {
    // App Check initialization failure should not break the app
    AppLogger.w('[Firebase] ⚠️ App Check initialization failed: $e');
    AppLogger.w(
      '[Firebase] ⚠️ Phone auth will still work, but without App Check validation',
    );
    AppLogger.w(
      '[Firebase] ⚠️ If you see throttling errors, ensure you\'re running in debug mode',
    );
  }
}

void main() async {
  // Ensure Flutter binding is initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with all security configurations
  await _initializeFirebase();

  // Create router and store globally for notification navigation
  appRouter = _createRouter();

  await PushNotificationManager.instance.initialize();

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider(create: (_) => EnergyDashboardController()),
        ChangeNotifierProvider(create: (_) => BudgetController()),
        ChangeNotifierProvider(create: (_) => VerificationService()),
        ChangeNotifierProvider(create: (_) => PhoneAuthService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => ChatNotificationController()),
        ChangeNotifierProvider(create: (_) => UserStatusService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Energy Smart',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
