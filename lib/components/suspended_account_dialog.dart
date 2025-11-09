import 'package:exercise_app/constants/constant.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

/// Suspended account dialog shown when user status is "suspended"
/// This dialog is non-dismissible and only disappears when status becomes "active"
class SuspendedAccountDialog extends StatelessWidget {
  const SuspendedAccountDialog({super.key});

  /// Show the suspended account dialog
  /// This dialog cannot be dismissed by tapping outside or back button
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(178),
      builder: (context) => const SuspendedAccountDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Prevent dismissing with back button
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.md),
        ),
        elevation: 8,
        backgroundColor: isDarkMode ? AppColor.surfaceDark : AppColor.surface,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.withAlpha(77), width: 2),
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
              // Warning icon
              Container(
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withAlpha(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withAlpha(51),
                      Colors.orange.withAlpha(26),
                    ],
                  ),
                ),
                child: const Icon(
                  Iconsax.warning_2,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: Insets.lg),
              // Suspended title
              Text(
                'Account Suspended',
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
              // Suspension message
              Text(
                'Your account has been suspended. Please contact support for assistance.',
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
              // Contact Support button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Close dialog and navigate to chat page
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    // Use a small delay to ensure dialog is closed before navigation
                    Future.microtask(() {
                      if (context.mounted) {
                        context.go('/supportChat');
                      }
                    });
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
                      const Icon(
                        Iconsax.message_text_1,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        'Contact Support',
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
      ),
    );
  }
}
