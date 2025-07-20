import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';

class EnergyInsights extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const EnergyInsights({required this.responsiveFontSize, super.key});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy Insights',
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: responsiveFontSize(context, 14),
                    color: AppColor.lowConsumption,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          Container(
            padding: EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColor.lowConsumption.withAlpha((0.2 * 255).toInt()),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.lamp_charge,
                  color: AppColor.lowConsumption,
                  size: 20,
                ),
                SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'You can save ₱12 this month by adjusting AC temperature by 2°C',
                    style: TextStyle(
                      fontSize: responsiveFontSize(context, 14),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
