import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/services/power_rate_service.dart';

class MonitoringHeaderCard extends StatefulWidget {
  final String selectedPeriod;
  const MonitoringHeaderCard({super.key, required this.selectedPeriod});

  @override
  State<MonitoringHeaderCard> createState() => _MonitoringHeaderCardState();
}

class _MonitoringHeaderCardState extends State<MonitoringHeaderCard> {
  final PowerRateService _powerRateService = PowerRateService();

  @override
  void initState() {
    super.initState();
    _powerRateService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _powerRateService,
      builder: (context, child) {
        final currentRate = _powerRateService.currentRate;

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
                        '₱${currentRate.toStringAsFixed(2)} / kWh',
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
      },
    );
  }
}
