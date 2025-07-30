import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';

class MonitoringStatusOverview extends StatelessWidget {
  const MonitoringStatusOverview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusCard(
            icon: Iconsax.flash_1,
            title: 'Current Rate',
            value: '₱10.25',
            subtitle: 'per kWh',
            color: AppColor.accentGreen,
          ),
        ),
        SizedBox(width: Insets.md),
        Expanded(
          child: _StatusCard(
            icon: Iconsax.activity,
            title: "Today's Usage",
            value: '7.2',
            subtitle: 'kWh',
            color: AppColor.mediumConsumption,
          ),
        ),
        SizedBox(width: Insets.md),
        Expanded(
          child: _StatusCard(
            icon: Iconsax.wallet,
            title: 'Est. Cost',
            value: '₱73.80',
            subtitle: 'today',
            color: AppColor.primary,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: Insets.sm),
          Text(title, style: ResponsiveText.label(context)),
          SizedBox(height: 2),
          Text(value, style: ResponsiveText.stat(context)),
          Text(subtitle, style: ResponsiveText.caption(context)),
        ],
      ),
    );
  }
}
