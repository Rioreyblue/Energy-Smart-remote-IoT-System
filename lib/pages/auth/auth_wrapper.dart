import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:exercise_app/pages/onboarding/onboarding_page.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/pages/auth/login_page.dart';
import 'package:exercise_app/pages/auth/verification_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      // Onboarding gate
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_onboarding') ?? false;
      _showOnboarding = !seen;

      // Check if user is logged in via SharedPreferences
      await _authService.getLoginState();

      // Also check Firebase Auth state
      _authService.currentUser;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleOnboardingComplete() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _showOnboarding = false;
    });

    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Get current route location
    final location = GoRouterState.of(context).uri.path;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.flash_on, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(
                'Loading Energy Smart...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingPage(onCompleted: _handleOnboardingComplete);
    }

    // Only handle routing logic for root path and auth-related paths
    // For other paths, let GoRouter handle them via redirects
    final isAuthPath =
        location == '/' ||
        location == '/login' ||
        location == '/register' ||
        location == '/onboarding' ||
        location == '/terms';

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
          );
        }

        final isAuthenticated = snapshot.hasData && snapshot.data != null;

        // If on a non-auth path, let GoRouter handle it (redirects will protect routes)
        if (!isAuthPath) {
          // For nested routes, GoRouter will render the child automatically
          // We just need to provide a container
          return const SizedBox.shrink();
        }

        // Handle auth-related paths
        if (isAuthenticated) {
          // When authenticated at root or auth paths, check verification status
          return FutureBuilder(
            future: _authService.getCurrentUserData(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                );
              }

              if (!userSnap.hasData || userSnap.data == null) {
                // If user data not found, show login
                return const NewLoginPage();
              }

              final user = userSnap.data!;

              // Check verification status
              return FutureBuilder<bool>(
                future: _authService.isUserFullyVerified(),
                builder: (context, verificationSnap) {
                  if (verificationSnap.connectionState ==
                      ConnectionState.waiting) {
                    return Scaffold(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      body: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    );
                  }

                  final isFullyVerified = verificationSnap.data ?? false;

                  // If fully verified and at root, redirect to home
                  if (isFullyVerified) {
                    if (location == '/') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && context.mounted) {
                          context.go('/home');
                        }
                      });
                      return Scaffold(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      );
                    }
                    // If on login/register while verified, redirect to home
                    if (location == '/login' || location == '/register') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && context.mounted) {
                          context.go('/home');
                        }
                      });
                      return Scaffold(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      );
                    }
                  }

                  // If not fully verified, show verification page
                  if (!isFullyVerified && location == '/') {
                    final emailVerified = user.isEmailVerified;
                    return VerificationPage(
                      verificationType: emailVerified ? 'phone' : 'email',
                      contactInfo:
                          emailVerified ? user.mobileNumber : user.email,
                      firstName: user.firstName,
                      lastName: user.lastName,
                      middleName: user.middleName,
                      mobileNumber: user.mobileNumber,
                      email: user.email,
                      energyProvider: user.energyProvider,
                      address: user.address,
                    );
                  }

                  // For other auth paths when authenticated but not verified, show login
                  return const NewLoginPage();
                },
              );
            },
          );
        } else {
          // User is not authenticated
          // Show login page at root, let GoRouter handle other paths
          if (location == '/') {
            return const NewLoginPage();
          }
          // For other auth paths when not authenticated, let GoRouter handle it
          return const SizedBox.shrink();
        }
      },
    );
  }
}
