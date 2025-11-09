import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/services/appliance_service.dart';
import 'package:exercise_app/models/appliance_model.dart';

class MonitoringStatusOverview extends StatefulWidget {
  const MonitoringStatusOverview({super.key});

  @override
  State<MonitoringStatusOverview> createState() =>
      _MonitoringStatusOverviewState();
}

class _MonitoringStatusOverviewState extends State<MonitoringStatusOverview> {
  final ApplianceService _applianceService = ApplianceService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ApplianceModel>>(
      stream: _applianceService.listenToAppliances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }

        final appliances = snapshot.data!;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final Color mutedColor = theme.colorScheme.onSurface.withAlpha(
          (isDark ? 150 : 170),
        );
        final activeAppliances = appliances.where((a) => a.isOn).toList();

        if (activeAppliances.isEmpty) {
          return Container(
            padding: EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withAlpha(isDark ? 80 : 30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Iconsax.warning_2, color: mutedColor, size: 20),
                SizedBox(width: Insets.sm),
                Text(
                  'No active appliances',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: mutedColor),
                ),
              ],
            ),
          );
        }

        final avgVoltage = _calculateAverageVoltage(activeAppliances);
        final totalCurrent = _calculateTotalCurrent(activeAppliances);
        final totalWatts = _calculateTotalWatts(activeAppliances);

        final Color voltageColor =
            isDark ? theme.colorScheme.tertiary : AppColor.accentGreen;
        final Color currentColor =
            isDark ? theme.colorScheme.secondary : AppColor.mediumConsumption;
        final Color wattsColor =
            isDark ? theme.colorScheme.primary : AppColor.primary;

        return Row(
          children: [
            Expanded(
              child: _StatusCard(
                icon: Iconsax.flash_1,
                title: 'Voltage',
                value: avgVoltage.toStringAsFixed(1),
                subtitle: 'V',
                color: voltageColor,
              ),
            ),
            SizedBox(width: Insets.md),
            Expanded(
              child: _StatusCard(
                icon: Iconsax.electricity,
                title: 'Current',
                value: totalCurrent.toStringAsFixed(2),
                subtitle: 'A',
                color: currentColor,
              ),
            ),
            SizedBox(width: Insets.md),
            Expanded(
              child: _StatusCard(
                icon: Iconsax.wind,
                title: 'Watts',
                value: totalWatts.toStringAsFixed(0),
                subtitle: 'W',
                color: wattsColor,
              ),
            ),
          ],
        );
      },
    );
  }

  double _calculateAverageVoltage(List<ApplianceModel> appliances) {
    if (appliances.isEmpty) return 0.0;
    double sum = 0.0;
    int count = 0;
    for (final appliance in appliances) {
      if (appliance.voltage != null && appliance.voltage! > 0) {
        sum += appliance.voltage!;
        count++;
      }
    }
    return count > 0 ? (sum / count) : 0.0;
  }

  double _calculateTotalCurrent(List<ApplianceModel> appliances) {
    double sum = 0.0;
    for (final appliance in appliances) {
      if (appliance.current != null && appliance.current! > 0) {
        sum += appliance.current!;
      }
    }
    return sum;
  }

  double _calculateTotalWatts(List<ApplianceModel> appliances) {
    double sum = 0.0;
    for (final appliance in appliances) {
      if (appliance.watts != null && appliance.watts! > 0) {
        sum += appliance.watts!.toDouble();
      }
    }
    return sum;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color shadowColor = theme.shadowColor.withAlpha(isDark ? 90 : 40);
    final Color surfaceColor = theme.colorScheme.surface;
    final Color titleColor = theme.colorScheme.onSurface.withAlpha(210);
    final Color valueColor = theme.colorScheme.onSurface;
    final Color subtitleColor = theme.colorScheme.onSurfaceVariant.withAlpha(
      200,
    );
    final Color iconColor =
        isDark ? color.withAlpha((0.85 * 255).toInt()) : color;

    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          SizedBox(height: Insets.sm),
          Text(
            title,
            style: ResponsiveText.label(context).copyWith(color: titleColor),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: ResponsiveText.stat(context).copyWith(color: valueColor),
          ),
          Text(
            subtitle,
            style: ResponsiveText.caption(
              context,
            ).copyWith(color: subtitleColor),
          ),
        ],
      ),
    );
  }
}
