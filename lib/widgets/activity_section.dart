import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';

class ActivitySection extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const ActivitySection({required this.responsiveFontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: responsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: Insets.md),
          _ActivityItem(
            icon: Iconsax.lamp,
            title: 'Living room lights turned off',
            time: '2 min ago',
            iconColor: AppColor.mediumConsumption,
            responsiveFontSize: responsiveFontSize,
          ),
          SizedBox(height: Insets.sm),
          _ActivityItem(
            icon: Iconsax.cloud_snow,
            title: 'AC temperature set to 22°C',
            time: '15 min ago',
            iconColor: AppColor.lowConsumption,
            responsiveFontSize: responsiveFontSize,
          ),
          SizedBox(height: Insets.sm),
          _ActivityItem(
            icon: Iconsax.wallet,
            title: 'Energy goal achieved!',
            time: '1 hour ago',
            iconColor: AppColor.accentGreen,
            responsiveFontSize: responsiveFontSize,
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final Color iconColor;
  final double Function(BuildContext, double) responsiveFontSize;
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.time,
    required this.iconColor,
    required this.responsiveFontSize,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: iconColor.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 12),
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
