import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';

enum SnackbarType { success, error, info, warning }

class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool showCloseButton = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = _getSnackbarConfig(type, colorScheme);

    final snackBar = SnackBar(
      content: _buildContent(
        message,
        config,
        actionLabel,
        onActionPressed,
        showCloseButton,
        context,
      ),
      backgroundColor: config.backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: config.borderColor, width: 1.5),
      ),
      elevation: 6,
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static Widget _buildContent(
    String message,
    _SnackbarConfig config,
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool showCloseButton,
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.backgroundColor,
            config.backgroundColor.withAlpha(230), // was withOpacity(0.9)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: config.iconBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: config.iconColor.withAlpha(
                      51,
                    ), // was withOpacity(0.2)
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(config.icon, color: config.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    config.title,
                    style: TextStyle(
                      color: config.titleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: config.messageColor,
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onActionPressed,
                style: TextButton.styleFrom(
                  foregroundColor: config.actionColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (showCloseButton) ...[
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: config.closeButtonColor,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static _SnackbarConfig _getSnackbarConfig(
    SnackbarType type,
    ColorScheme scheme,
  ) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarConfig(
          icon: Icons.check_circle_outline,
          title: 'Success',
          backgroundColor: const Color(0xFF10B981),
          iconColor: Colors.white,
          iconBackgroundColor: Colors.white.withAlpha(51),
          titleColor: Colors.white,
          messageColor: Colors.white.withAlpha(242),
          actionColor: Colors.white,
          closeButtonColor: Colors.white.withAlpha(204),
          borderColor: Colors.white.withAlpha(77),
        );

      case SnackbarType.error:
        return _SnackbarConfig(
          icon: Icons.error_outline,
          title: 'Error',
          backgroundColor: const Color(0xFFEF4444),
          iconColor: Colors.white,
          iconBackgroundColor: Colors.white.withAlpha(51),
          titleColor: Colors.white,
          messageColor: Colors.white.withAlpha(242),
          actionColor: Colors.white,
          closeButtonColor: Colors.white.withAlpha(204),
          borderColor: Colors.white.withAlpha(77),
        );

      case SnackbarType.warning:
        return _SnackbarConfig(
          icon: Icons.warning_amber_outlined,
          title: 'Warning',
          backgroundColor: const Color(0xFFF59E0B),
          iconColor: Colors.white,
          iconBackgroundColor: Colors.white.withAlpha(51),
          titleColor: Colors.white,
          messageColor: Colors.white.withAlpha(242),
          actionColor: Colors.white,
          closeButtonColor: Colors.white.withAlpha(204),
          borderColor: Colors.white.withAlpha(77),
        );

      case SnackbarType.info:
        return _SnackbarConfig(
          icon: Icons.info_outline,
          title: 'Info',
          backgroundColor: scheme.surfaceVariant,
          iconColor: scheme.primary,
          iconBackgroundColor: scheme.primary.withAlpha(26),
          titleColor: scheme.onSurface,
          messageColor: scheme.onSurface.withAlpha(204),
          actionColor: scheme.primary,
          closeButtonColor: scheme.onSurface.withAlpha(153),
          borderColor: scheme.outline.withAlpha(77),
        );
    }
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(
      context,
      message,
      type: SnackbarType.success,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(
      context,
      message,
      type: SnackbarType.error,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(
      context,
      message,
      type: SnackbarType.warning,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(
      context,
      message,
      type: SnackbarType.info,
      duration: duration ?? const Duration(seconds: 2),
    );
  }
}

class _SnackbarConfig {
  final IconData icon;
  final String title;
  final Color backgroundColor;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color titleColor;
  final Color messageColor;
  final Color actionColor;
  final Color closeButtonColor;
  final Color borderColor;

  const _SnackbarConfig({
    required this.icon,
    required this.title,
    required this.backgroundColor,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.titleColor,
    required this.messageColor,
    required this.actionColor,
    required this.closeButtonColor,
    required this.borderColor,
  });
}
