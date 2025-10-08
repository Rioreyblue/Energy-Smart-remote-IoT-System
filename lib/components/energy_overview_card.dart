import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';

class EnergyOverviewCard extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const EnergyOverviewCard({required this.responsiveFontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        final currentUsage = controller.getCurrentUsage();
        final conversionValue = controller.getConversionValue();
        final todaysCost = controller.getTodaysCost();
        final targetCost = controller.getTargetCost();
        final thisMonth = controller.getThisMonthConsumption();

        return Container(
          padding: EdgeInsets.all(Insets.xm - 1),
          decoration: BoxDecoration(
            color: AppColor.accentGreen.withAlpha(128),
            borderRadius: BorderRadius.circular(Insets.lg),
          ),
          child: Container(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      controller.formatKwh(currentUsage),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsiveFontSize(context, 36),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Iconsax.convertshape5,
                      color: AppColor.surface.withAlpha(180),
                    ),
                    Text(
                      controller.formatCurrency(conversionValue),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsiveFontSize(context, 28),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Insets.xm),
                Row(
                  children: [
                    const Icon(
                      Iconsax.trend_down,
                      color: Colors.amber,
                      size: 16,
                    ),
                    SizedBox(width: Insets.xm),
                    // Text(
                    //   '12% vs yesterday',
                    //   style: TextStyle(
                    //     color: Colors.white.withAlpha((0.9 * 255).toInt()),
                    //     fontSize: responsiveFontSize(context, 14),
                    //   ),
                    // ),
                  ],
                ),
                SizedBox(height: Insets.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _OverviewItem(
                      label: "Today's Cost",
                      value: controller.formatCurrency(todaysCost),
                      responsiveFontSize: responsiveFontSize,
                    ),
                    _OverviewItem(
                      label: 'Target Cost',
                      value: controller.formatCurrency(targetCost),
                      responsiveFontSize: responsiveFontSize,
                    ),
                    _OverviewItem(
                      label: 'This Month',
                      value: controller.formatCurrency(thisMonth),
                      responsiveFontSize: responsiveFontSize,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
