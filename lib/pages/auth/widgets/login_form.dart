import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Login form widget with email and password fields
class LoginForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email Field
          _buildEmailField()
              .animate()
              .fadeIn(delay: 200.ms)
              .slideX(begin: 0.1, end: 0, delay: 200.ms),
          const SizedBox(height: 20),

          // Password Field
          _buildPasswordField()
              .animate()
              .fadeIn(delay: 300.ms)
              .slideX(begin: 0.1, end: 0, delay: 300.ms),
          const SizedBox(height: 12),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onForgotPassword,
              child: Text(
                'Forgot Password?',
                style: ResponsiveText.body(context).copyWith(
                  color: AppColor.accentGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 24),

          // Sign In Button
          _buildSignInButton()
              .animate()
              .fadeIn(delay: 500.ms)
              .scale(
                delay: 500.ms,
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
              ),

          const SizedBox(height: 16),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.disabled),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 16),

          // Google Sign In Button
          _buildGoogleSignInButton().animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: widget.emailController,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColor.accentRed, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: widget.passwordController,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColor.accentRed, width: 2),
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
      onPressed: () {
        if (widget.formKey.currentState!.validate()) {
          // Handle sign in
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColor.accentGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: const Text(
        'Sign In',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return OutlinedButton.icon(
      onPressed: widget.onGoogleSignIn,
      icon: const Icon(Icons.android, color: AppColor.textPrimary),
      label: Text(
        'Sign in with Google',
        style: TextStyle(color: AppColor.textPrimary),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
