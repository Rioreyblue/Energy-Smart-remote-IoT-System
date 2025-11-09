import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'theme_switch_button.dart';
import '../services/auth_service.dart';
import '../widgets/app_snackbar.dart';
import '../controllers/chat_notification_controller.dart';
import '../services/chat_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColor.surface : AppColor.primary;
    final textPrimary =
        isDark ? AppColor.textPrimaryDark : AppColor.textPrimary;
    final textSecondary =
        isDark ? AppColor.textSecondaryDark : AppColor.textSecondary;
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(
            context,
            isDark,
            primaryColor,
            textPrimary,
            textSecondary,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader(context, 'Help & Support', primaryColor),
                _buildDrawerItem(
                  context,
                  icon: Iconsax.lamp_on,
                  title: 'Tips & Advice',
                  subtitle: 'Energy saving tips',
                  route: '/tipsAdvice',
                  iconColor: AppColor.accentGreen,
                  textColor: textPrimary,
                  subtitleColor: textSecondary,
                ),
                _buildDrawerItem(
                  context,
                  icon: Iconsax.info_circle,
                  title: 'FAQ / Help Center',
                  subtitle: 'Find answers quickly',
                  route: '/faqHelpCenter',
                  iconColor: AppColor.accentGreen,
                  textColor: textPrimary,
                  subtitleColor: textSecondary,
                ),
                _buildSupportChatItem(
                  context,
                  iconColor: AppColor.accentGreen,
                  textColor: textPrimary,
                  subtitleColor: textSecondary,
                ),
                _buildDrawerItem(
                  context,
                  icon: Iconsax.user_tag,
                  title: 'Contact Admin',
                  subtitle: 'Get direct support',
                  route: '/contactAdmin',
                  iconColor: AppColor.accentGreen,
                  textColor: textPrimary,
                  subtitleColor: textSecondary,
                ),
                const SizedBox(height: Insets.lg),
                _buildSectionHeader(context, 'Account', primaryColor),
                _buildLogoutItem(
                  context,
                  icon: Iconsax.logout,
                  title: 'Sign Out',
                  subtitle: 'Logout from your account',
                  iconColor: AppColor.accentRed,
                  textColor: textPrimary,
                  subtitleColor: textSecondary,
                ),
                const SizedBox(height: Insets.xl),
              ],
            ),
          ),
          _buildDrawerFooter(context, isDark, primaryColor, textSecondary),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColor.accentGreen,
            AppColor.lowConsumption.withAlpha(204), // 0.8 * 255 = 204
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51), // 0.2 * 255 = 51
                  borderRadius: BorderRadius.circular(Insets.md),
                ),
                child: Icon(Iconsax.flash_1, color: Colors.white, size: 32),
              ),
              const SizedBox(height: Insets.lg),
              // Optionally add a title here
              const SizedBox(height: Insets.xm),
              Text(
                'Smart energy management',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(230), // 0.9 * 255 = 230
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: primaryColor.withAlpha(178), // 0.7 * 255 = 178
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required Color iconColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Insets.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Insets.md),
          onTap: () {
            Navigator.pop(context);
            context.go(route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.md,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.xm),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(26), // 0.1 * 255 = 26
                    borderRadius: BorderRadius.circular(Insets.sm),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subtitleColor.withAlpha(
                            178,
                          ), // 0.7 * 255 = 178
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  color:
                      isDark
                          ? AppColor.disabled.withAlpha(178)
                          : AppColor.primary.withAlpha(178),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build Support Chat item with unread badge
  Widget _buildSupportChatItem(
    BuildContext context, {
    required Color iconColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Insets.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Insets.md),
          onTap: () {
            Navigator.pop(context);
            context.go('/supportChat');
            // Mark as read when opened
            final chatNotificationController =
                Provider.of<ChatNotificationController>(context, listen: false);
            final chatService = Provider.of<ChatService>(
              context,
              listen: false,
            );
            if (chatService.currentChatId != null) {
              chatNotificationController.markAsRead(chatService.currentChatId!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.md,
            ),
            child: Consumer<ChatNotificationController>(
              builder: (context, chatController, child) {
                final unreadCount = chatController.unreadCount;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Insets.xm),
                      decoration: BoxDecoration(
                        color: iconColor.withAlpha(26), // 0.1 * 255 = 26
                        borderRadius: BorderRadius.circular(Insets.sm),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Iconsax.message_text_1,
                            color: iconColor,
                            size: 20,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColor.accentRed,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 12,
                                  minHeight: 12,
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Support Chat',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColor.accentRed,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            unreadCount > 0
                                ? '$unreadCount unread message${unreadCount > 1 ? 's' : ''}'
                                : 'Get instant help from our team',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: subtitleColor.withAlpha(
                                178,
                              ), // 0.7 * 255 = 178
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Iconsax.arrow_right_3,
                      color:
                          isDark
                              ? AppColor.disabled.withAlpha(178)
                              : AppColor.primary.withAlpha(178),
                      size: 16,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Insets.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Insets.md),
          onTap: () async {
            Navigator.pop(context);
            await _handleLogout(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.md,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.xm),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(26), // 0.1 * 255 = 26
                    borderRadius: BorderRadius.circular(Insets.sm),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subtitleColor.withAlpha(
                            178,
                          ), // 0.7 * 255 = 178
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  color:
                      isDark
                          ? AppColor.disabled.withAlpha(178)
                          : AppColor.primary.withAlpha(178),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final authService = AuthService();
      await authService.signOut();

      if (context.mounted) {
        AppSnackbar.showSuccess(context, 'Successfully signed out');
        // Navigate to root - AuthWrapper will handle showing login page
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Failed to sign out: ${e.toString()}');
      }
    }
  }

  Widget _buildDrawerFooter(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color:
                isDark
                    ? AppColor.surfaceDark.withAlpha(51)
                    : AppColor.surface.withAlpha(51),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColor.backgroundDark : AppColor.background,
              borderRadius: BorderRadius.circular(Insets.md),
            ),
            child: Row(
              children: [
                Icon(Iconsax.moon, color: primaryColor, size: 20),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    'Dark Mode',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color:
                          isDark
                              ? AppColor.textPrimaryDark
                              : AppColor.textPrimary,
                    ),
                  ),
                ),
                ThemeSwitchTile(),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                'Energy Smart',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textSecondary.withAlpha(153), // 0.6 * 255 = 153
                  fontSize: 12,
                ),
              ),
              Text(
                'Developed By: Team Oasis',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textSecondary.withAlpha(153), // 0.6 * 255 = 153
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
