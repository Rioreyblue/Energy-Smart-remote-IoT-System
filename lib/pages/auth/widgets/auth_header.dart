import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Header widget for auth screens with logo and tagline
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App Logo
        Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColor.accentGreen.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.flash_circle,
                size: 64,
                color: AppColor.accentGreen,
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(delay: 100.ms, duration: 400.ms),

        const SizedBox(height: 24),

        // Title
        Text(
              title,
              style: ResponsiveText.title(context).copyWith(
                fontWeight: FontWeight.bold,
                color: AppColor.textPrimary,
              ),
              textAlign: TextAlign.center,
            )
            .animate()
            .fadeIn(delay: 300.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0, delay: 300.ms),

        const SizedBox(height: 8),

        // Subtitle
        Text(
              subtitle,
              style: ResponsiveText.body(
                context,
              ).copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
            )
            .animate()
            .fadeIn(delay: 400.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0, delay: 400.ms),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Alternative header with gradient background
class GradientAuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const GradientAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.accentGreen, AppColor.primary],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.flash_circle, size: 80, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'EnergySmart',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor · Save · Empower',
            style: TextStyle(fontSize: 16, color: Colors.white.withAlpha(230)),
          ),
        ],
      ),
    );
  }
}
