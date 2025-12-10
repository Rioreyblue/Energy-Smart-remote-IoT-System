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
      // Check if user is logged in via SharedPreferences
      await _authService.getLoginState();

      // Also check Firebase Auth state
      _authService.currentUser;

      // Re-check onboarding status (in case user just signed in)
      await _checkOnboardingStatus();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Check onboarding status - should only show once on fresh install
  /// This ensures onboarding only appears once, even if auth state changes
  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_onboarding') ?? false;

      // Only show onboarding in AuthWrapper if:
      // 1. It hasn't been seen
      // 2. User is NOT authenticated (fresh install scenario)
      // If user is authenticated, they should access onboarding via /onboarding route
      final user = _authService.currentUser;
      final shouldShowOnboarding = !seen && user == null;

      if (mounted) {
        setState(() {
          _showOnboarding = shouldShowOnboarding;
        });
      }
    } catch (e) {
      // If error checking, default to not showing onboarding
      if (mounted) {
        setState(() {
          _showOnboarding = false;
        });
      }
    }
  }

  Future<void> _handleOnboardingComplete() async {
    if (!mounted) {
      return;
    }

    // Mark onboarding as seen
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);
    } catch (e) {
      // Log error but continue
    }

    setState(() {
      _showOnboarding = false;
    });

    if (!mounted) {
      return;
    }

    // Check if user is authenticated - if yes, proceed to verification/home
    // If not, go to login
    final user = _authService.currentUser;
    if (user != null) {
      // User is authenticated, check verification status
      final isFullyVerified = await _authService.isUserFullyVerified();
      if (isFullyVerified) {
        context.go('/home');
      } else {
        // Not verified, go to root which will show verification page
        context.go('/');
      }
    } else {
      // Not authenticated, go to login
      context.go('/login');
    }
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
        location == '/terms' ||
        location == '/sms';

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

        // If user becomes authenticated, hide onboarding (they've already seen it or will see it via /onboarding route)
        if (isAuthenticated && _showOnboarding) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _showOnboarding = false;
              });
            }
          });
        }

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

                  // Check session OTP verification (required on every login)
                  return FutureBuilder<bool>(
                    future: _authService.isSessionOtpVerified(),
                    builder: (context, sessionOtpSnap) {
                      if (sessionOtpSnap.connectionState ==
                          ConnectionState.waiting) {
                        return Scaffold(
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          body: Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        );
                      }

                      final sessionOtpVerified = sessionOtpSnap.data ?? false;

                      // Always require session OTP verification, even if phone is already verified
                      // Only allow home access if both fully verified AND session OTP verified
                      if (isFullyVerified && sessionOtpVerified) {
                        if (location == '/') {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && context.mounted) {
                              context.go('/home');
                            }
                          });
                          return Scaffold(
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
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
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            body: Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          );
                        }
                        // Allow /sms even if already verified so we can enforce OTP on each login
                        if (location == '/sms') {
                          return const SizedBox.shrink();
                        }
                      }

                      // If not fully verified OR session OTP not verified, require verification
                      if (!isFullyVerified || !sessionOtpVerified) {
                        // Allow /sms route for phone verification
                        if (location == '/sms') {
                          // Let GoRouter handle the /sms route (PhoneEntryPage)
                          return const SizedBox.shrink();
                        }

                        // Show verification page at root
                        if (location == '/') {
                          final emailVerified = user.isEmailVerified;
                          // Always show phone verification if session OTP not verified
                          final verificationType =
                              (!sessionOtpVerified || emailVerified)
                                  ? 'phone'
                                  : 'email';
                          return VerificationPage(
                            verificationType: verificationType,
                            contactInfo:
                                verificationType == 'phone'
                                    ? user.mobileNumber
                                    : user.email,
                            firstName: user.firstName,
                            lastName: user.lastName,
                            middleName: user.middleName,
                            mobileNumber: user.mobileNumber,
                            email: user.email,
                            energyProvider: user.energyProvider,
                            address: user.address,
                          );
                        }
                      }

                      // For other auth paths when authenticated but not verified, show login
                      return const NewLoginPage();
                    },
                  );
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
