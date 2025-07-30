import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';

class MonitoringHeaderCard extends StatelessWidget {
  final String selectedPeriod;
  const MonitoringHeaderCard({Key? key, required this.selectedPeriod})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.xm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Insets.lg),
        color: AppColor.accentGreen.withAlpha(128),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(Insets.sm),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColor.lowConsumption, AppColor.accentGreen],
          ),
          borderRadius: BorderRadius.circular(Insets.lg),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Iconsax.flash_circle, color: Colors.white, size: 28),
                SizedBox(width: Insets.md),
                Text(
                  'Current Power Rate',
                  style: ResponsiveText.title(
                    context,
                  ).copyWith(color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: Insets.sm),
            Row(
              children: [
                Icon(
                  Iconsax.location_tick,
                  color: Colors.white.withAlpha(178),
                  size: 18,
                ),
                SizedBox(width: Insets.sm),
                Text(
                  'Energy Provider: Moelci Uno',
                  style: ResponsiveText.label(
                    context,
                  ).copyWith(color: Colors.white.withAlpha(230)),
                ),
                Spacer(),
                Center(
                  child: Text(
                    '₱10.25 / kWh',
                    style: ResponsiveText.body(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
