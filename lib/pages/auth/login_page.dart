import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';
import 'package:exercise_app/pages/auth/widgets/auth_animation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exercise_app/services/phone_auth_service.dart';
import 'package:provider/provider.dart';

/// Modern, redesigned login page with split-screen layout and Lottie animations
class NewLoginPage extends StatefulWidget {
  const NewLoginPage({super.key});

  @override
  State<NewLoginPage> createState() => _NewLoginPageState();
}

class _NewLoginPageState extends State<NewLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _showSuccessAnimation = false;

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final dialogFormKey = GlobalKey<FormState>();

    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'Reset password',
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your account email to receive a reset link.',
                  style: ResponsiveText.body(context).copyWith(
                    color:
                        theme.textTheme.bodyMedium?.color ??
                        AppColor.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                    labelStyle: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    hintStyle: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    prefixIcon: Icon(
                      Iconsax.sms,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Please enter your email';
                    if (!RegExp(
                      r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                    ).hasMatch(v)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!dialogFormKey.currentState!.validate()) return;
                final email = resetEmailController.text.trim();
                try {
                  await _authService.sendPasswordResetEmail(email);
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    AppSnackbar.showSuccess(
                      context,
                      'Password reset email sent to $email',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackbar.showError(context, e.toString());
                  }
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        setState(() {
          _showSuccessAnimation = true;
        });

        // Wait a moment to show success animation
        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;

        // Always require phone verification after sign in
        try {
          final phoneAuthService = context.read<PhoneAuthService>();
          phoneAuthService.reset();

          // Send OTP to user's phone number
          await _authService.sendPhoneVerificationOtp(user.mobileNumber);

          if (mounted) {
            AppSnackbar.showSuccess(
              context,
              'OTP sent to ${user.mobileNumber}. Please enter the code to verify.',
            );
            // Navigate to root - AuthWrapper will show verification page
            context.go('/');
          }
        } catch (e) {
          if (mounted) {
            AppSnackbar.showWarning(
              context,
              'Failed to send OTP: ${e.toString()}. Please enter your phone number.',
            );
            // Navigate to SMS entry page on error
            context.go('/sms');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Incorrect email or password. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        setState(() {
          _showSuccessAnimation = true;
        });

        // Wait a moment to show success animation
        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;

        // Check if user is truly new (just created) vs existing
        // New users have empty mobileNumber and haven't completed onboarding
        final isNewUser =
            user.mobileNumber.isEmpty &&
            user.energyProvider.isEmpty &&
            user.address.isEmpty;

        // Check if onboarding was seen
        final prefs = await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

        // For existing users, mark onboarding as seen to prevent future issues
        if (!isNewUser && !seenOnboarding) {
          await prefs.setBool('seen_onboarding', true);
        }

        // Only show onboarding for truly new users who haven't seen it
        if (isNewUser && !seenOnboarding) {
          // New user - navigate to onboarding first
          if (mounted) {
            context.go('/onboarding');
            return;
          }
        }

        // Existing user or onboarding completed - proceed with verification
        // Always require phone verification after Google sign in
        final phoneAuthService = context.read<PhoneAuthService>();
        phoneAuthService.reset();

        final hasPhoneNumber =
            user.mobileNumber.isNotEmpty && user.mobileNumber.trim().isNotEmpty;

        if (hasPhoneNumber) {
          try {
            // Send OTP to user's phone number
            await _authService.sendPhoneVerificationOtp(user.mobileNumber);

            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                'OTP sent to ${user.mobileNumber}. Please enter the code to verify.',
              );
              // Navigate to root - AuthWrapper will show verification page
              context.go('/');
            }
          } catch (e) {
            if (mounted) {
              AppSnackbar.showWarning(
                context,
                'Failed to send OTP: ${e.toString()}. Please enter your phone number.',
              );
              // Navigate to SMS entry page on error
              context.go('/sms');
            }
          }
        } else {
          if (mounted) {
            AppSnackbar.showInfo(
              context,
              'Please enter your phone number to complete verification.',
            );
            context.go('/sms');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Failed to sign in with Google. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 900;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body:
          isSmallScreen
              ? _buildMobileLayout(isDark, theme)
              : _buildDesktopLayout(isDark, theme),
    );
  }

  Widget _buildDesktopLayout(bool isDark, ThemeData theme) {
    return Row(
      children: [
        // Left Panel - Animation & Branding
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColor.accentGreen.withAlpha(26),
                  theme.colorScheme.primary.withAlpha(13),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AuthAnimation(
                        animationPath: 'assets/A_4.json',
                        width: 300,
                        height: 300,
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 24),
                  Text(
                    'EnergySmart',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColor.accentGreen,
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 12),
                  Text(
                    'Monitor · Save · Empower',
                    style: TextStyle(
                      fontSize: 18,
                      color:
                          theme.textTheme.bodyMedium?.color ??
                          AppColor.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 48),
                  AuthAnimation(
                    animationPath:
                        _showSuccessAnimation
                            ? 'assets/A_2.json'
                            : 'assets/A_4.json',
                    width: 300,
                    height: 300,
                    loop: !_showSuccessAnimation,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right Panel - Login Form
        Expanded(
          flex: 1,
          child: Container(
            color: theme.colorScheme.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildLoginCard(isDark, theme),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top Section - Logo and Animation
          Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColor.accentGreen.withAlpha(31),
                  theme.colorScheme.primary.withAlpha(15),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AuthAnimation(
                  animationPath: 'assets/A_1.json',
                  width: 160,
                  height: 160,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Login Form
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildLoginCard(isDark, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(bool isDark, ThemeData theme) {
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColor.textPrimary;
    final secondaryTextColor =
        theme.textTheme.bodyMedium?.color ?? AppColor.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withAlpha(51)
                    : Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColor.accentGreen.withAlpha(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Header
            Text(
              'Sign In',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
            const SizedBox(height: 8),
            Text(
              'Enter your credentials to continue',
              style: ResponsiveText.body(
                context,
              ).copyWith(color: secondaryTextColor),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
            const SizedBox(height: 40),

            // Email Field
            _buildEmailField()
                .animate()
                .fadeIn(delay: 300.ms)
                .slideX(begin: 0.1, end: 0),
            const SizedBox(height: 20),

            // Password Field
            _buildPasswordField()
                .animate()
                .fadeIn(delay: 400.ms)
                .slideX(begin: 0.1, end: 0),
            const SizedBox(height: 12),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Forgot Password?',
                  style: ResponsiveText.body(context).copyWith(
                    color: AppColor.accentGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sign In Button
            _buildSignInButton()
                .animate()
                .fadeIn(delay: 500.ms)
                .scale(delay: 500.ms, begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 24),

            // Divider with OR
            Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final dividerColor = (theme.textTheme.bodyMedium?.color ??
                        AppColor.textSecondary)
                    .withAlpha(77);
                return Row(
                  children: [
                    Expanded(child: Divider(color: dividerColor, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: ResponsiveText.body(context).copyWith(
                          color:
                              theme.textTheme.bodyMedium?.color ??
                              AppColor.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: dividerColor, thickness: 1)),
                  ],
                );
              },
            ).animate().fadeIn(delay: 550.ms),

            const SizedBox(height: 24),

            // Google Sign In Button
            _buildGoogleSignInButton()
                .animate()
                .fadeIn(delay: 600.ms)
                .scale(delay: 600.ms, begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 24),

            // Register Link
            Builder(
              builder: (context) {
                final theme = Theme.of(context);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: ResponsiveText.body(context).copyWith(
                        color:
                            theme.textTheme.bodyMedium?.color ??
                            AppColor.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.go('/register');
                      },
                      child: Text(
                        'Sign Up',
                        style: ResponsiveText.body(context).copyWith(
                          color: AppColor.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        prefixIcon: Icon(Iconsax.sms, color: theme.textTheme.bodyMedium?.color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColor.accentGreen, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter your email';
        final v = value.trim();
        if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        prefixIcon: Icon(
          Iconsax.lock,
          color: theme.textTheme.bodyMedium?.color,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
            color: theme.textTheme.bodyMedium?.color,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColor.accentGreen, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildSignInButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColor.accentGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child:
          _isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : const Text(
                'Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.accentGreen, AppColor.lowConsumption],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withAlpha(77),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isGoogleLoading || _isLoading) ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isGoogleLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google Icon
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Image.asset(
                        'assets/images/g_logo.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to icon if image not found
                          return Icon(
                            Icons.g_mobiledata,
                            size: 18,
                            // color: const Color(0xFF4285F4),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Gmail',
                      style: ResponsiveText.body(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
