import 'package:exercise_app/constants/constant.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Welcome dialog shown after successful login
class WelcomeDialog extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final VoidCallback onContinue;

  const WelcomeDialog({
    super.key,
    this.userName,
    this.userEmail,
    required this.onContinue,
  });

  /// Show the welcome dialog
  static Future<void> show(
    BuildContext context, {
    String? userName,
    String? userEmail,
    required VoidCallback onContinue,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => WelcomeDialog(
            userName: userName,
            userEmail: userEmail,
            onContinue: onContinue,
          ),
    );
  }

  String _getGreeting() {
    if (userName != null && userName!.isNotEmpty) {
      // Extract first name if full name is provided
      final firstName = userName!.split(' ').first;
      return 'Welcome back, $firstName!';
    } else if (userEmail != null && userEmail!.isNotEmpty) {
      // Extract name from email if available
      final emailName = userEmail!.split('@').first;
      return 'Welcome back, $emailName!';
    } else {
      return 'Welcome back!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.md),
      ),
      elevation: 4,
      backgroundColor: isDarkMode ? AppColor.surfaceDark : AppColor.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isDarkMode
                    ? AppColor.textPrimaryDark.withAlpha(77)
                    : AppColor.textSecondary.withAlpha(77),
            width: 2,
          ),
          borderRadius: BorderRadius.all(Radius.circular(Insets.md)),
        ),
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Welcome icon with animation
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.accentGreen.withAlpha(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColor.accentGreen.withAlpha(51),
                    AppColor.lowConsumption.withAlpha(26),
                  ],
                ),
              ),
              child: Icon(
                Iconsax.tick_circle,
                size: 48,
                color: AppColor.accentGreen,
              ),
            ),
            const SizedBox(height: Insets.lg),
            // Welcome title
            Text(
              _getGreeting(),
              style: ResponsiveText.title(context).copyWith(
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode
                        ? AppColor.textPrimaryDark
                        : AppColor.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.md),
            // Welcome message
            Text(
              'You\'re all set to start managing your energy consumption. Let\'s make your home more energy efficient!',
              style: ResponsiveText.body(context).copyWith(
                color:
                    isDarkMode
                        ? AppColor.textSecondaryDark
                        : AppColor.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.xl),
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onContinue();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: Insets.md,
                    horizontal: Insets.lg,
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Get Started',
                      style: ResponsiveText.body(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    const Icon(
                      Iconsax.arrow_right_3,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
