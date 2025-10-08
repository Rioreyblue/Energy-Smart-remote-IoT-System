import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';

class Header extends StatelessWidget {
  final String username;
  final double Function(BuildContext, double) responsiveFontSize;
  const Header({
    required this.username,
    required this.responsiveFontSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello There!',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 16),
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsiveFontSize(context, 28),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.05 * 255).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Iconsax.home),
                onPressed: () {},
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(width: Insets.sm),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.05 * 255).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Iconsax.notification),
                onPressed: () {},
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
