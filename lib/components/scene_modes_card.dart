import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'scene_modes.dart';

class SceneModesCard extends StatelessWidget {
  final ScenePreset preset;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const SceneModesCard({
    required this.preset,
    required this.isActive,
    required this.onTap,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isActiveState = isActive && !isLoading;
    final activeBgColor =
        brightness == Brightness.dark ? AppColor.primaryDark : AppColor.primary;
    final activeBorderColor = AppColor.accentGreen;
    final inactiveBgColor =
        brightness == Brightness.dark ? AppColor.surfaceDark : AppColor.surface;
    final inactiveBorderColor = AppColor.disabled;
    final iconColor =
        isActiveState ? AppColor.accentGreen : AppColor.textPrimary;
    final textColor =
        isActiveState
            ? (brightness == Brightness.dark
                ? AppColor.textPrimaryDark
                : AppColor.accentGreen)
            : AppColor.textPrimary;
    final backgroundColor = isActiveState ? activeBgColor : inactiveBgColor;
    final borderColor = isActiveState ? activeBorderColor : inactiveBorderColor;
    final shadowColor =
        brightness == Brightness.dark
            ? AppColor.primaryDark.withAlpha(25)
            : AppColor.primary.withAlpha(25);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            if (isActiveState)
              BoxShadow(
                color: activeBorderColor.withAlpha(51),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(preset.icon, color: iconColor, size: 24),
                if (isLoading)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        iconColor.withAlpha(178),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: Insets.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                // Optionally show device summary here
              ],
            ),
          ],
        ),
      ),
    );
  }
}
