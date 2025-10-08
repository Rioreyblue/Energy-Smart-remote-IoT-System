import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/pages/auth/login_page.dart';
import 'package:exercise_app/home_screen.dart';
import 'package:exercise_app/pages/auth/verification_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;

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

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

        // Check if user is authenticated
        if (snapshot.hasData && snapshot.data != null) {
          // When authenticated, load merged user data (Firestore profile + RTDB live)
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
                return const LoginPage();
              }

              final user = userSnap.data!;

              // Check verification status using the service methods
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

                  if (isFullyVerified) {
                    return const HomeScreen();
                  }

                  // Determine which verification is needed
                  final emailVerified = user.isEmailVerified;

                  return VerificationPage(
                    verificationType: emailVerified ? 'phone' : 'email',
                    contactInfo: emailVerified ? user.mobileNumber : user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    middleName: user.middleName,
                    mobileNumber: user.mobileNumber,
                    email: user.email,
                    energyProvider: user.energyProvider,
                    address: user.address,
                  );
                },
              );
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
