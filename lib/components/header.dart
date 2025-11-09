import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/services/profile_service.dart';
import 'package:exercise_app/utils/app_logger.dart';

class Header extends StatefulWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const Header({required this.responsiveFontSize, super.key});

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
          ],
        );
      },
    );
  }
}
