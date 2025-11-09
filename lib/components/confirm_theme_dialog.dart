import 'package:exercise_app/constants/constant.dart';
import 'package:flutter/material.dart';

class AppDialog extends StatelessWidget {
  final Widget icon;
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color? confirmButtonColor;
  final Color? cancelButtonColor;

  const AppDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    this.confirmButtonColor,
    this.cancelButtonColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      backgroundColor: isDarkMode ? AppColor.surface : AppColor.surfaceDark,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color:
                (isDarkMode
                    ? AppColor.textPrimary
                    : AppColor.textSecondaryDark),
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
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDarkMode ? AppColor.primary : AppColor.surface)
                    .withAlpha(26),
              ),
              child: icon,
            ),
            const SizedBox(height: Insets.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    isDarkMode
                        ? AppColor.textPrimary
                        : AppColor.textPrimaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    isDarkMode
                        ? AppColor.textSecondary
                        : AppColor.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          cancelButtonColor ??
                          (isDarkMode
                              ? AppColor.textSecondary
                              : AppColor.textSecondaryDark),
                      side: BorderSide(
                        color:
                            cancelButtonColor ??
                            (isDarkMode
                                ? AppColor.textSecondary
                                : AppColor.textSecondaryDark),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: Insets.md),
                    ),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          confirmButtonColor ??
                          (isDarkMode
                              ? AppColor.accentGreen
                              : AppColor.primary),
                      foregroundColor:
                          isDarkMode ? AppColor.textPrimaryDark : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: Insets.md),
                      elevation: 0,
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ConfirmThemeDialog extends StatelessWidget {
  final bool isDark;
  const ConfirmThemeDialog({required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icon(
        isDark ? Icons.nightlight_round : Icons.wb_sunny,
        color: isDark ? AppColor.surface : AppColor.surfaceDark,
        size: 32,
      ),
      title: isDark ? 'Switch to Dark Mode?' : 'Switch to Light Mode?',
      message: 'Your app will restart to apply the theme changes',
      cancelText: 'Cancel',
      confirmText: 'Switch',
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: () => Navigator.of(context).pop(true),
      confirmButtonColor: isDark ? AppColor.accentGreen : AppColor.primary,
    );
  }
}
