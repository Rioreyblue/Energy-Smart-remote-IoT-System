import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/services/profile_service.dart';
import 'package:exercise_app/utils/app_logger.dart';

class Header extends StatefulWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final AnimationController? refreshAnimation;
  const Header({
    required this.responsiveFontSize,
    this.onRefresh,
    this.isRefreshing = false,
    this.refreshAnimation,
    super.key,
  });

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  late ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _profileService.initialize();
  }

  @override
  void dispose() {
    _profileService.dispose();
    super.dispose();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Iconsax.user,
        size: 32,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _profileService,
      builder: (context, child) {
        if (_profileService.isLoading) {
          return Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              const SizedBox(width: Insets.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello There!',
                    style: TextStyle(
                      fontSize: widget.responsiveFontSize(context, 16),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        final fullName =
            _profileService.fullName.isNotEmpty
                ? _profileService.fullName
                : 'User';
        final email =
            _profileService.email.isNotEmpty ? _profileService.email : '';
        final hasProfilePhoto = _profileService.hasProfilePhoto;
        final profilePhotoUrl = _profileService.profilePhotoUrl;

        // Debug logging for profile data
        final photoUrlDisplay =
            profilePhotoUrl.isNotEmpty
                ? (profilePhotoUrl.length > 50
                    ? '${profilePhotoUrl.substring(0, 50)}...'
                    : profilePhotoUrl)
                : 'empty';
        AppLogger.d(
          'Header: Profile data - fullName: $fullName, email: $email, hasProfilePhoto: $hasProfilePhoto, profilePhotoUrl: $photoUrlDisplay',
        );

        final brightness = Theme.of(context).brightness;
        final isDark = brightness == Brightness.dark;

        return Row(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ClipOval(
                child:
                    hasProfilePhoto
                        ? Image.network(
                          profilePhotoUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            AppLogger.e(
                              'Header: Failed to load profile image from URL: $profilePhotoUrl. Error: $error',
                            );
                            return _buildDefaultAvatar();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 48,
                              height: 48,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                        : _buildDefaultAvatar(),
              ),
            ),
            const SizedBox(width: Insets.md),
            // Name and Email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello There!',
                    style: TextStyle(
                      fontSize: widget.responsiveFontSize(context, 16),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    fullName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.responsiveFontSize(context, 28),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.responsiveFontSize(context, 12),
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withAlpha(153),
                      ),
                    ),
                ],
              ),
            ),
            // Refresh Button
            if (widget.onRefresh != null)
              widget.refreshAnimation != null
                  ? AnimatedBuilder(
                    animation: widget.refreshAnimation!,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle:
                            widget.isRefreshing
                                ? widget.refreshAnimation!.value * 2 * 3.14159
                                : 0,
                        child: IconButton(
                          onPressed:
                              widget.isRefreshing ? null : widget.onRefresh,
                          icon: Icon(
                            Iconsax.refresh,
                            color:
                                widget.isRefreshing
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withAlpha(128)
                                    : (isDark
                                        ? AppColor.accentGreen
                                        : Theme.of(
                                          context,
                                        ).colorScheme.primary),
                            size: 20,
                          ),
                          tooltip:
                              widget.isRefreshing
                                  ? 'Refreshing...'
                                  : 'Refresh all sections',
                          style: IconButton.styleFrom(
                            backgroundColor: (isDark
                                    ? AppColor.accentGreen
                                    : Theme.of(context).colorScheme.primary)
                                .withAlpha(26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.all(Insets.sm),
                          ),
                        ),
                      );
                    },
                  )
                  : IconButton(
                    onPressed: widget.onRefresh,
                    icon: Icon(
                      Iconsax.refresh,
                      color:
                          isDark
                              ? AppColor.accentGreen
                              : Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    tooltip: 'Refresh all sections',
                    style: IconButton.styleFrom(
                      backgroundColor: (isDark
                              ? AppColor.accentGreen
                              : Theme.of(context).colorScheme.primary)
                          .withAlpha(26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.all(Insets.sm),
                    ),
                  ),
          ],
        );
      },
    );
  }
}
