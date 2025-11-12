import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/constant.dart';

class UserTypePromptDialog extends StatelessWidget {
  const UserTypePromptDialog({super.key, required this.onProceed});

  final VoidCallback onProceed;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onProceed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserTypePromptDialog(onProceed: onProceed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.md),
      ),
      backgroundColor: isDark ? AppColor.surfaceDark : AppColor.surface,
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.accentGreen.withAlpha(32),
              ),
              child: const Icon(
                Iconsax.flash,
                size: 48,
                color: AppColor.accentGreen,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'Choose Your Energy Profile',
              style: ResponsiveText.title(context).copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Before controlling devices, tell us whether you\'re managing a household or a small business. This helps us customise recommendations and goals for you.',
              style: ResponsiveText.body(context).copyWith(
                color:
                    isDark
                        ? AppColor.textSecondaryDark
                        : AppColor.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: Insets.md,
                    horizontal: Insets.lg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Insets.sm),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.flash_circle, color: Colors.white),
                    const SizedBox(width: Insets.sm),
                    Text(
                      'Choose user type',
                      style: ResponsiveText.body(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
