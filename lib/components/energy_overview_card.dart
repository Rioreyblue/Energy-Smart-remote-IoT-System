import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';

class EnergyOverviewCard extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const EnergyOverviewCard({required this.responsiveFontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.lowConsumption, AppColor.accentGreen],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColor.lowConsumption.withAlpha((0.3 * 255).toInt()),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Usage',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).toInt()),
                  fontSize: responsiveFontSize(context, 16),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsiveFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.sm),
          Text(
            '2.4 kW',
            style: TextStyle(
              color: Colors.white,
              fontSize: responsiveFontSize(context, 36),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: Insets.xm),
          Row(
            children: [
              const Icon(Iconsax.trend_down, color: Colors.amber, size: 16),
              SizedBox(width: Insets.xm),
              Text(
                '12% vs yesterday',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.9 * 255).toInt()),
                  fontSize: responsiveFontSize(context, 14),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _OverviewItem(
                label: "Today's Cost",
                value: '₱4.20',
                responsiveFontSize: responsiveFontSize,
              ),
              _OverviewItem(
                label: 'Target Cost',
                value: '₱127.50',
                responsiveFontSize: responsiveFontSize,
              ),
              _OverviewItem(
                label: 'This Month',
                value: '₱127.50',
                responsiveFontSize: responsiveFontSize,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final String label;
  final String value;
  final double Function(BuildContext, double) responsiveFontSize;
  const _OverviewItem({
    required this.label,
    required this.value,
    required this.responsiveFontSize,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.8 * 255).toInt()),
            fontSize: responsiveFontSize(context, 12),
          ),
        ),
        SizedBox(height: Insets.xm),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: responsiveFontSize(context, 18),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
