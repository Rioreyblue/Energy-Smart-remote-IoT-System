import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../models/appliance_model.dart';

class EnergyInsights extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  final VoidCallback? onViewAllPressed;

  const EnergyInsights({
    required this.responsiveFontSize,
    this.onViewAllPressed,
    super.key,
  });

  /// Calculate dynamic insight based on appliance usage
  Map<String, String> _calculateInsight(
    List<ApplianceModel> appliances,
    double powerRate,
  ) {
    if (appliances.isEmpty) {
      return {
        'message': 'Add appliances to get personalized energy insights',
        'icon': 'lamp_charge',
      };
    }

    // Calculate monthly cost projection for each appliance
    // Assuming current kWh is cumulative, we project monthly based on current usage
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;

    // Find highest consuming appliance by cost
    ApplianceModel? highestCostAppliance;
    double highestMonthlyCost = 0.0;

    for (final appliance in appliances) {
      // Calculate monthly cost projection for each appliance
      double monthlyKwh = 0.0;

      // Priority 1: If we have actual usage data (kWh), project based on current month progress
      if (appliance.kwh > 0 && daysElapsed > 0) {
        // Project monthly: (current kwh / days elapsed) * days in month
        // Add safety check to avoid division by very small numbers
        monthlyKwh = (appliance.kwh / daysElapsed) * daysInMonth;
      }
      // Priority 2: If appliance is currently on and has watts, estimate based on live usage
      else if (appliance.isOn &&
          appliance.watts != null &&
          appliance.watts! > 0) {
        // Estimate based on typical usage patterns
        // High wattage (>1000W): estimate 6-8 hours/day, Medium: 4-6 hours, Low: 2-4 hours
        final hoursPerDay =
            appliance.watts! > 1000
                ? 7.0
                : (appliance.watts! > 500 ? 5.0 : 3.0);
        monthlyKwh = (appliance.watts! * hoursPerDay * daysInMonth) / 1000.0;
      }
      // Priority 3: If we have historical usage time and watts, calculate from that
      else if (appliance.watts != null &&
          appliance.watts! > 0 &&
          appliance.totalUsageTime != null &&
          appliance.totalUsageTime! > 0) {
        // Calculate from total usage time: convert seconds to hours, then to kWh
        final totalHours = appliance.totalUsageTime! / 3600.0;
        // Project monthly based on historical usage pattern
        if (daysElapsed > 0) {
          final dailyHours = totalHours / daysElapsed;
          monthlyKwh = (appliance.watts! * dailyHours * daysInMonth) / 1000.0;
        }
      }
      // Priority 4: Fallback - estimate from watts only
      else if (appliance.watts != null && appliance.watts! > 0) {
        final hoursPerDay = appliance.watts! > 1000 ? 6.0 : 4.0;
        monthlyKwh = (appliance.watts! * hoursPerDay * daysInMonth) / 1000.0;
      }

      // Only consider appliances with meaningful consumption
      if (monthlyKwh > 0) {
        final monthlyCost = monthlyKwh * powerRate;

        if (monthlyCost > highestMonthlyCost) {
          highestMonthlyCost = monthlyCost;
          highestCostAppliance = appliance;
        }
      }
    }

    // Generate insight message
    if (highestCostAppliance == null || highestMonthlyCost <= 0) {
      return {
        'message':
            'Start using your appliances to get energy saving recommendations',
        'icon': 'lamp_charge',
      };
    }

    // Calculate potential savings (15% reduction)
    final savingsPercentage = 15;
    final potentialSavings = highestMonthlyCost * (savingsPercentage / 100);

    // Format appliance name
    final applianceName =
        highestCostAppliance.name.isNotEmpty
            ? highestCostAppliance.name
            : _formatApplianceId(highestCostAppliance.id);

    // Generate recommendation based on appliance characteristics
    String recommendation;
    final watts = highestCostAppliance.watts ?? 0;
    final iconName = highestCostAppliance.icon.toLowerCase();

    if (iconName.contains('wind') ||
        iconName.contains('snow') ||
        applianceName.toLowerCase().contains('ac') ||
        applianceName.toLowerCase().contains('air') ||
        applianceName.toLowerCase().contains('conditioner')) {
      // Cooling/heating appliance
      recommendation = 'adjusting temperature by 2°C';
    } else if (watts > 1000) {
      // High wattage appliance
      recommendation = 'reducing daily usage by 1 hour';
    } else if (highestCostAppliance.isOn &&
        (highestCostAppliance.totalUsageTime ?? 0) > 43200) {
      // Always-on appliance (more than 12 hours)
      recommendation = 'optimizing power settings';
    } else {
      // General recommendation
      recommendation = 'reducing usage by $savingsPercentage%';
    }

    return {
      'message':
          'You can save ₱${potentialSavings.toStringAsFixed(0)} this month by $recommendation on $applianceName',
      'icon': 'lamp_charge',
    };
  }

  /// Format appliance ID to readable name
  String _formatApplianceId(String applianceId) {
    if (applianceId.startsWith('appliances_')) {
      final number = applianceId.replaceAll('appliances_', '');
      return 'Appliance $number';
    }
    return applianceId
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, homeController, child) {
        final appliances = homeController.appliances;
        final powerRate = homeController.currentRate;
        final insight = _calculateInsight(appliances, powerRate);

        return Container(
          padding: EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
                    onPressed: onViewAllPressed,
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
                    color: AppColor.lowConsumption.withAlpha(
                      (0.2 * 255).toInt(),
                    ),
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
                        insight['message']!,
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
      },
    );
  }
}
