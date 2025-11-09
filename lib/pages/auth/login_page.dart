import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';
import 'package:exercise_app/pages/auth/widgets/auth_animation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exercise_app/services/phone_auth_service.dart';
import 'package:provider/provider.dart';
import 'package:exercise_app/components/welcome_dialog.dart';
import 'package:exercise_app/models/user_model.dart';

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

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your account email to receive a reset link.',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Iconsax.sms),
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
              child: const Text('Cancel'),
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
        final isPhoneVerified = user.isPhoneVerified;
        setState(() {
          _showSuccessAnimation = true;
        });

        // Wait a moment to show success animation
        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;

        if (isPhoneVerified) {
          await _showWelcomeAndNavigate(user);
        } else {
          context.read<PhoneAuthService>().reset();
          context.go('/sms');
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
        final isPhoneVerified = user.isPhoneVerified;
        setState(() {
          _showSuccessAnimation = true;
        });

        // Wait a moment to show success animation
        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;

        if (isPhoneVerified) {
          await _showWelcomeAndNavigate(user);
        } else {
          context.read<PhoneAuthService>().reset();
          context.go('/sms');
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

    return Scaffold(
      body: isSmallScreen ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
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
                  AppColor.primary.withAlpha(13),
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
                  const Text(
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
                      color: AppColor.textSecondary,
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
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildLoginCard(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
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
                  AppColor.primary.withAlpha(15),
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
          Padding(padding: const EdgeInsets.all(24), child: _buildLoginCard()),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
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
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColor.textPrimary,
              ),
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
            const SizedBox(height: 8),
            Text(
              'Enter your credentials to continue',
              style: ResponsiveText.body(
                context,
              ).copyWith(color: AppColor.textSecondary),
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
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppColor.textSecondary.withAlpha(77),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppColor.textSecondary.withAlpha(77),
                    thickness: 1,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 550.ms),

            const SizedBox(height: 24),

            // Google Sign In Button
            _buildGoogleSignInButton()
                .animate()
                .fadeIn(delay: 600.ms)
                .scale(delay: 600.ms, begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 24),

            // Register Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
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
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        prefixIcon: const Icon(Iconsax.sms),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
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
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Iconsax.lock),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Iconsax.eye_slash : Iconsax.eye),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
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

  Future<void> _showWelcomeAndNavigate(UserModel user) async {
    final displayName = user.displayName.trim();
    final name =
        displayName.isNotEmpty
            ? displayName
            : user.firstName.trim().isNotEmpty
            ? user.firstName.trim()
            : '';

    await WelcomeDialog.show(
      context,
      userName: name.isNotEmpty ? name : null,
      userEmail: user.email,
      onContinue: () {
        context.go('/home');
      },
    );
  }
}
