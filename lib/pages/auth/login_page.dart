import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';
import 'package:exercise_app/pages/auth/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Welcome back, ${user.displayName}!',
          );
          // Navigation will be handled by the auth wrapper
        }
      } else {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Login failed. Please check your credentials.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: Insets.xxl * 2),

              // Logo and Title
              _buildHeader(context, isDark),

              SizedBox(height: Insets.xxl * 2),

              // Login Form
              _buildLoginForm(context, isDark),

              SizedBox(height: Insets.lg),

              // Register Link
              _buildRegisterLink(context),

              SizedBox(height: Insets.lg),

              // Forgot Password
              _buildForgotPassword(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      children: [
        // App Logo/Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColor.accentGreen, AppColor.lowConsumption],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColor.accentGreen.withAlpha(64),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          // child: Icon(Iconsax.flash_1, color: Colors.white, size: 50),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
            'assets/icon/update_icon.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          )
        ),

        SizedBox(height: Insets.lg),

        // App Name
        Text(
          'Energy Smart',
          style: ResponsiveText.headline(
            context,
          ).copyWith(color: AppColor.primary, fontWeight: FontWeight.bold),
        ),

        SizedBox(height: Insets.sm),

        // Subtitle
        Text(
          'Sign in to manage your energy consumption',
          style: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Field
            _buildEmailField(context),

            SizedBox(height: Insets.lg),

            // Password Field
            _buildPasswordField(context),

            SizedBox(height: Insets.xl),

            // Login Button
            _buildLoginButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            prefixIcon: Icon(Iconsax.sms, color: AppColor.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.accentGreen, width: 2),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _signIn(),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: Icon(Iconsax.lock, color: AppColor.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Iconsax.eye : Iconsax.eye_slash,
                color: AppColor.primary,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.accentGreen, width: 2),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColor.accentGreen, AppColor.lowConsumption],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColor.accentGreen.withAlpha(64),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isLoading
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.login, color: Colors.white),
                    SizedBox(width: Insets.sm),
                    Text(
                      'Sign In',
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

  Widget _buildRegisterLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.textSecondary),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            );
          },
          child: Text(
            'Register here',
            style: ResponsiveText.body(context).copyWith(
              color: AppColor.accentGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword(BuildContext context) {
    return TextButton(
      onPressed: () async {
        if (_emailController.text.isEmpty) {
          AppSnackbar.showError(
            context,
            'Please enter your email address first',
          );
          return;
        }

        try {
          await _authService.sendPasswordResetEmail(
            _emailController.text.trim(),
          );
          if (mounted) {
            AppSnackbar.showSuccess(
              context,
              'Password reset email sent to ${_emailController.text}',
            );
          }
        } catch (e) {
          if (mounted) {
            AppSnackbar.showError(context, e.toString());
          }
        }
      },
      child: Text(
        'Forgot Password?',
        style: ResponsiveText.body(
          context,
        ).copyWith(color: AppColor.primary, fontWeight: FontWeight.w500),
      ),
    );
  }
}
