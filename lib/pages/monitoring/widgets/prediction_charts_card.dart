// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:exercise_app/constants/constant.dart';
// import 'package:exercise_app/services/predictive_dataset_service.dart';
// import 'package:exercise_app/models/predictive_data_model.dart';
// import 'package:exercise_app/models/prediction_result_model.dart';

// class PredictionChartsCard extends StatelessWidget {
//   final PredictionResultModel? prediction;

//   const PredictionChartsCard({super.key, this.prediction});

//   @override
//   Widget build(BuildContext context) {
//     final datasetService = PredictiveDatasetService();

//     if (!datasetService.hasDataset) {
//       return const SizedBox.shrink();
//     }

//     return Column(
//       children: [
//         // 3-Month kWh Trends Chart
//         _ChartCard(
//           title: '3-Month kWh Trends by Appliance',
//           child: _buildLineChart(context, datasetService.dataset),
//         ),
//         SizedBox(height: Insets.lg),

//         // Cost Comparison Chart
//         _ChartCard(
//           title: 'Cost per Appliance Comparison',
//           child: _buildBarChart(context, datasetService.dataset),
//         ),
//       ],
//     );
//   }

//   Widget _buildLineChart(
//     BuildContext context,
//     List<PredictiveDataModel> dataset,
//   ) {
//     final applianceGroups = <String, List<PredictiveDataModel>>{};

//     // Group by appliance
//     for (final data in dataset) {
//       applianceGroups.putIfAbsent(data.appliance, () => []).add(data);
//     }

//     // Get unique months and sort
//     final months = dataset.map((d) => d.month).toSet().toList();
//     months.sort();

//     // Limit to last 3 months
//     final recentMonths =
//         months.length > 3 ? months.sublist(months.length - 3) : months;

//     // Build spots for each appliance
//     final applianceColors = [
//       AppColor.accentGreen,
//       AppColor.lowConsumption,
//       AppColor.mediumConsumption,
//       AppColor.primary,
//       AppColor.accentRed,
//     ];
//     final lineBarsData = <LineChartBarData>[];

//     int colorIndex = 0;
//     // Store cost data for tooltips
//     final costDataMap = <int, double>{};

//     for (final entry in applianceGroups.entries) {
//       final spots = <FlSpot>[];

//       for (int i = 0; i < recentMonths.length; i++) {
//         final month = recentMonths[i];
//         final monthData = entry.value.where((d) => d.month == month).toList();
//         final totalKwh = monthData
//             .map((d) => d.energyKwh)
//             .fold(0.0, (sum, kwh) => sum + kwh);
//         final totalCost = monthData
//             .map((d) => d.cost)
//             .fold(0.0, (sum, cost) => sum + cost);
//         spots.add(FlSpot(i.toDouble(), totalKwh));
//         // Store cost for this month index (aggregate across all appliances)
//         costDataMap[i] = (costDataMap[i] ?? 0.0) + totalCost;
//       }

//       if (spots.isNotEmpty) {
//         lineBarsData.add(
//           LineChartBarData(
//             spots: spots,
//             isCurved: true,
//             color: applianceColors[colorIndex % applianceColors.length],
//             barWidth: 3,
//             isStrokeCapRound: true,
//             dotData: FlDotData(show: true),
//             belowBarData: BarAreaData(show: false),
//           ),
//         );
//         colorIndex++;
//       }
//     }

//     // Add prediction forecast line if available
//     final predictionCostDataMap = <int, double>{};
//     if (prediction != null && prediction!.applianceBreakdown != null) {
//       final predictionSpots = <FlSpot>[];
//       for (int i = 0; i < recentMonths.length + 1; i++) {
//         if (i < recentMonths.length) {
//           // Historical data points
//           double totalKwh = 0;
//           double totalCost = 0;
//           for (final entry in applianceGroups.entries) {
//             final month = recentMonths[i];
//             final monthData =
//                 entry.value.where((d) => d.month == month).toList();
//             totalKwh += monthData
//                 .map((d) => d.energyKwh)
//                 .fold(0.0, (sum, kwh) => sum + kwh);
//             totalCost += monthData
//                 .map((d) => d.cost)
//                 .fold(0.0, (sum, cost) => sum + cost);
//           }
//           predictionSpots.add(FlSpot(i.toDouble(), totalKwh));
//           predictionCostDataMap[i] = totalCost;
//         } else {
//           // Prediction point
//           predictionSpots.add(FlSpot(i.toDouble(), prediction!.predictedKwh));
//           // Use predicted cost from prediction model
//           if (prediction!.predictedCost > 0) {
//             predictionCostDataMap[i] = prediction!.predictedCost;
//           }
//         }
//       }

//       lineBarsData.add(
//         LineChartBarData(
//           spots: predictionSpots,
//           isCurved: true,
//           color: AppColor.accentRed.withAlpha(200),
//           barWidth: 3,
//           dashArray: [5, 5],
//           isStrokeCapRound: true,
//           dotData: FlDotData(
//             show: true,
//             getDotPainter: (spot, percent, barData, index) {
//               if (index == predictionSpots.length - 1) {
//                 return FlDotCirclePainter(
//                   radius: 5,
//                   color: AppColor.accentRed,
//                   strokeWidth: 2,
//                   strokeColor: Colors.white,
//                 );
//               }
//               return FlDotCirclePainter(radius: 0);
//             },
//           ),
//           belowBarData: BarAreaData(show: false),
//         ),
//       );
//     }

//     final maxY = _calculateMaxValue(dataset, useCost: false) * 1.2;

//     return SizedBox(
//       height: 220,
//       child: LineChart(
//         LineChartData(
//           minY: 0,
//           maxY: maxY,
//           gridData: FlGridData(
//             show: true,
//             horizontalInterval: maxY / 5,
//             getDrawingHorizontalLine:
//                 (value) => FlLine(
//                   color: AppColor.disabled.withAlpha((0.2 * 255).toInt()),
//                   strokeWidth: 1,
//                 ),
//           ),
//           titlesData: FlTitlesData(
//             bottomTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 interval: 1,
//                 reservedSize: 30,
//                 getTitlesWidget: (value, meta) {
//                   final idx = value.toInt();
//                   if (idx >= 0 && idx < recentMonths.length) {
//                     return Padding(
//                       padding: EdgeInsets.only(top: 8),
//                       child: Text(
//                         recentMonths[idx].split(' ').first,
//                         style: ResponsiveText.caption(context),
//                       ),
//                     );
//                   }
//                   if (prediction != null && idx == recentMonths.length) {
//                     return Padding(
//                       padding: EdgeInsets.only(top: 8),
//                       child: Text(
//                         'Predicted',
//                         style: ResponsiveText.caption(context).copyWith(
//                           color: AppColor.accentRed,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     );
//                   }
//                   return Text('');
//                 },
//               ),
//             ),
//             leftTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 interval: maxY / 5,
//                 reservedSize: 40,
//                 getTitlesWidget: (value, meta) {
//                   return Text(
//                     value.toStringAsFixed(0),
//                     style: ResponsiveText.caption(context),
//                   );
//                 },
//               ),
//             ),
//             topTitles: const AxisTitles(
//               sideTitles: SideTitles(showTitles: false),
//             ),
//             rightTitles: const AxisTitles(
//               sideTitles: SideTitles(showTitles: false),
//             ),
//           ),
//           borderData: FlBorderData(show: true),
//           lineBarsData: lineBarsData,
//           lineTouchData: LineTouchData(
//             touchTooltipData: LineTouchTooltipData(
//               getTooltipItems: (List<LineBarSpot> touchedSpots) {
//                 return touchedSpots.map((spot) {
//                   final monthIndex = spot.x.toInt();
//                   // Get cost for this month (from either costDataMap or predictionCostDataMap)
//                   final cost =
//                       costDataMap[monthIndex] ??
//                       predictionCostDataMap[monthIndex] ??
//                       0.0;

//                   // Check if this is a prediction spot (last point)
//                   final isPrediction =
//                       prediction != null && monthIndex == recentMonths.length;

//                   final costText =
//                       cost > 0 ? '\n₱${cost.toStringAsFixed(2)}' : '';

//                   return LineTooltipItem(
//                     '${spot.y.toStringAsFixed(2)} kWh$costText',
//                     ResponsiveText.label(context).copyWith(
//                       color: isPrediction ? AppColor.accentRed : Colors.white,
//                     ),
//                   );
//                 }).toList();
//               },
//               getTooltipColor: (spots) {
//                 // Default color, will be overridden by individual tooltip items
//                 return AppColor.primary.withAlpha(230);
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBarChart(
//     BuildContext context,
//     List<PredictiveDataModel> dataset,
//   ) {
//     final applianceGroups = <String, List<PredictiveDataModel>>{};

//     for (final data in dataset) {
//       applianceGroups.putIfAbsent(data.appliance, () => []).add(data);
//     }

//     final bars = <BarChartGroupData>[];
//     final appliances = applianceGroups.keys.toList();
//     final applianceColors = [
//       AppColor.accentGreen,
//       AppColor.lowConsumption,
//       AppColor.mediumConsumption,
//       AppColor.primary,
//       AppColor.accentRed,
//     ];

//     for (int i = 0; i < appliances.length; i++) {
//       final appliance = appliances[i];
//       final totalCost = applianceGroups[appliance]!
//           .map((d) => d.cost)
//           .fold(0.0, (sum, cost) => sum + cost);

//       bars.add(
//         BarChartGroupData(
//           x: i,
//           barRods: [
//             BarChartRodData(
//               toY: totalCost,
//               color: applianceColors[i % applianceColors.length],
//               width: 20,
//               borderRadius: BorderRadius.circular(4),
//             ),
//           ],
//         ),
//       );
//     }

//     final maxCost =
//         bars.isNotEmpty
//             ? bars
//                 .map((b) => b.barRods.first.toY)
//                 .reduce((a, b) => a > b ? a : b)
//             : 100.0;
//     final maxY = maxCost * 1.2;

//     return SizedBox(
//       height: 220,
//       child: BarChart(
//         BarChartData(
//           minY: 0,
//           maxY: maxY,
//           gridData: FlGridData(
//             show: true,
//             horizontalInterval: maxY / 5,
//             getDrawingHorizontalLine:
//                 (value) => FlLine(
//                   color: AppColor.disabled.withAlpha((0.2 * 255).toInt()),
//                   strokeWidth: 1,
//                 ),
//           ),
//           titlesData: FlTitlesData(
//             bottomTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 interval: 1,
//                 reservedSize: 40,
//                 getTitlesWidget: (value, meta) {
//                   final idx = value.toInt();
//                   if (idx >= 0 && idx < appliances.length) {
//                     final appliance = appliances[idx];
//                     return Padding(
//                       padding: EdgeInsets.only(top: 8),
//                       child: Text(
//                         appliance.length > 10
//                             ? '${appliance.substring(0, 10)}...'
//                             : appliance,
//                         style: ResponsiveText.caption(context),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     );
//                   }
//                   return Text('');
//                 },
//               ),
//             ),
//             leftTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 interval: maxY / 5,
//                 reservedSize: 40,
//                 getTitlesWidget: (value, meta) {
//                   return Text(
//                     '₱${value.toStringAsFixed(0)}',
//                     style: ResponsiveText.caption(context),
//                   );
//                 },
//               ),
//             ),
//             topTitles: const AxisTitles(
//               sideTitles: SideTitles(showTitles: false),
//             ),
//             rightTitles: const AxisTitles(
//               sideTitles: SideTitles(showTitles: false),
//             ),
//           ),
//           borderData: FlBorderData(show: true),
//           barGroups: bars,
//           barTouchData: BarTouchData(
//             touchTooltipData: BarTouchTooltipData(
//               getTooltipItem: (group, groupIndex, rod, rodIndex) {
//                 final appliance = appliances[groupIndex];
//                 final cost = rod.toY;
//                 return BarTooltipItem(
//                   '$appliance\n₱${cost.toStringAsFixed(2)}',
//                   ResponsiveText.label(context),
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   double _calculateMaxValue(
//     List<PredictiveDataModel> dataset, {
//     required bool useCost,
//   }) {
//     if (dataset.isEmpty) return 100.0;

//     if (useCost) {
//       return dataset.map((d) => d.cost).reduce((a, b) => a > b ? a : b);
//     } else {
//       return dataset.map((d) => d.energyKwh).reduce((a, b) => a > b ? a : b);
//     }
//   }
// }

// class _ChartCard extends StatelessWidget {
//   final String title;
//   final Widget child;

//   const _ChartCard({required this.title, required this.child});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xl),
//       margin: EdgeInsets.only(bottom: Insets.md),
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surface,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withAlpha((0.05 * 255).toInt()),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: ResponsiveText.stat(context)),
//           SizedBox(height: Insets.lg),
//           child,
//           SizedBox(height: Insets.md),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/predictive_dataset_service.dart';
import 'package:exercise_app/services/appliance_alias_service.dart';
import 'package:exercise_app/models/predictive_data_model.dart';
import 'package:exercise_app/models/prediction_result_model.dart';
import 'package:iconsax/iconsax.dart';

/// Color scheme helper for prediction charts with dark/light mode support
class _PredictionChartColors {
  final Color primaryColor;
  final Color surfaceColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color gridLineColor;
  final Color borderColor;
  final Color tooltipBackgroundColor;
  final Color tooltipTextColor;
  final Color shadowColor;
  final List<Color> applianceColors;

  _PredictionChartColors({
    required this.primaryColor,
    required this.surfaceColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.gridLineColor,
    required this.borderColor,
    required this.tooltipBackgroundColor,
    required this.tooltipTextColor,
    required this.shadowColor,
    required this.applianceColors,
  });

  factory _PredictionChartColors.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _PredictionChartColors(
      primaryColor: isDark ? AppColor.accentGreen : AppColor.primary,
      surfaceColor: isDark ? AppColor.surfaceDark : AppColor.surface,
      textColor: isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
      secondaryTextColor:
          isDark ? AppColor.textSecondaryDark : AppColor.textSecondary,
      gridLineColor:
          isDark
              ? AppColor.textSecondaryDark.withAlpha(80)
              : AppColor.disabled.withAlpha((0.2 * 255).toInt()),
      borderColor:
          isDark
              ? AppColor.textSecondaryDark.withAlpha(110)
              : AppColor.disabled.withAlpha((0.3 * 255).toInt()),
      tooltipBackgroundColor:
          isDark
              ? AppColor.primaryDark.withAlpha((0.95 * 255).toInt())
              : AppColor.primary.withAlpha((0.95 * 255).toInt()),
      tooltipTextColor: isDark ? AppColor.textPrimaryDark : Colors.white,
      shadowColor:
          isDark
              ? Colors.black.withAlpha(90)
              : Colors.black.withAlpha((0.05 * 255).toInt()),
      applianceColors: [
        AppColor.accentGreen,
        AppColor.lowConsumption,
        AppColor.mediumConsumption,
        AppColor.primary,
        AppColor.accentRed,
      ],
    );
  }
}

class PredictionChartsCard extends StatefulWidget {
  final PredictionResultModel? prediction;

  const PredictionChartsCard({super.key, this.prediction});

  @override
  State<PredictionChartsCard> createState() => _PredictionChartsCardState();
}

class _PredictionChartsCardState extends State<PredictionChartsCard> {
  final ApplianceAliasService _aliasService = ApplianceAliasService();
  Map<String, String> _applianceAliases = {};

  @override
  void initState() {
    super.initState();
    _loadApplianceAliases();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh aliases when page becomes visible again (e.g., after renaming)
    _loadApplianceAliases();
  }

  Future<void> _loadApplianceAliases() async {
    try {
      final aliases = await _aliasService.getAliases();
      if (mounted) {
        setState(() {
          _applianceAliases = aliases;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _applianceAliases = {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final datasetService = PredictiveDatasetService();

    if (!datasetService.hasDataset) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 3-Month kWh Trends Chart
        _ChartCard(
          title: '3-Month Energy Trends by Appliance',
          subtitle:
              'Track energy consumption patterns across your appliances over the last 3 months',
          child: _buildLineChart(context, datasetService.dataset),
        ),
        SizedBox(height: Insets.lg),

        // Cost Comparison Chart
        _ChartCard(
          title: 'Cost Comparison by Appliance',
          subtitle:
              'Compare total energy costs for each appliance to identify high-impact areas',
          child: _buildBarChart(context, datasetService.dataset),
        ),
      ],
    );
  }

  Widget _buildLineChart(
    BuildContext context,
    List<PredictiveDataModel> dataset,
  ) {
    final chartColors = _PredictionChartColors.fromContext(context);
    final applianceGroups = <String, List<PredictiveDataModel>>{};

    // Group by appliance
    for (final data in dataset) {
      applianceGroups.putIfAbsent(data.appliance, () => []).add(data);
    }

    // Get unique months and sort
    final months = dataset.map((d) => d.month).toSet().toList();
    months.sort();

    // Limit to last 3 months
    final recentMonths =
        months.length > 3 ? months.sublist(months.length - 3) : months;

    // Build spots for each appliance with metadata
    final lineBarsData = <LineChartBarData>[];
    final applianceMetadata = <String, Map<String, dynamic>>{};
    int colorIndex = 0;

    // Store cost data for tooltips (aggregated by month)
    final costDataMap = <int, double>{};

    for (final entry in applianceGroups.entries) {
      final appliance = entry.key;
      final spots = <FlSpot>[];
      final monthDataMap = <int, Map<String, double>>{};

      for (int i = 0; i < recentMonths.length; i++) {
        final month = recentMonths[i];
        final monthData = entry.value.where((d) => d.month == month).toList();
        final totalKwh = monthData
            .map((d) => d.energyKwh)
            .fold(0.0, (sum, kwh) => sum + kwh);
        final totalCost = monthData
            .map((d) => d.cost)
            .fold(0.0, (sum, cost) => sum + cost);
        spots.add(FlSpot(i.toDouble(), totalKwh));
        monthDataMap[i] = {'kwh': totalKwh, 'cost': totalCost};
        // Store cost for this month index (aggregate across all appliances)
        costDataMap[i] = (costDataMap[i] ?? 0.0) + totalCost;
      }

      if (spots.isNotEmpty) {
        final color =
            chartColors.applianceColors[colorIndex %
                chartColors.applianceColors.length];
        lineBarsData.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: chartColors.surfaceColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withAlpha((0.1 * 255).toInt()),
            ),
          ),
        );
        applianceMetadata[appliance] = {
          'color': color,
          'monthData': monthDataMap,
          'index': colorIndex,
        };
        colorIndex++;
      }
    }

    // Calculate max values including prediction
    double maxKwh = _calculateMaxValue(dataset, useCost: false);

    // Add prediction forecast line if available
    final predictionCostDataMap = <int, double>{};
    if (widget.prediction != null &&
        widget.prediction!.applianceBreakdown != null) {
      final predictionSpots = <FlSpot>[];
      for (int i = 0; i < recentMonths.length + 1; i++) {
        if (i < recentMonths.length) {
          // Historical data points
          double totalKwh = 0;
          double totalCost = 0;
          for (final entry in applianceGroups.entries) {
            final month = recentMonths[i];
            final monthData =
                entry.value.where((d) => d.month == month).toList();
            totalKwh += monthData
                .map((d) => d.energyKwh)
                .fold(0.0, (sum, kwh) => sum + kwh);
            totalCost += monthData
                .map((d) => d.cost)
                .fold(0.0, (sum, cost) => sum + cost);
          }
          predictionSpots.add(FlSpot(i.toDouble(), totalKwh));
          predictionCostDataMap[i] = totalCost;
        } else {
          // Prediction point
          predictionSpots.add(
            FlSpot(i.toDouble(), widget.prediction!.predictedKwh),
          );
          // Update max if prediction is higher
          if (widget.prediction!.predictedKwh > maxKwh) {
            maxKwh = widget.prediction!.predictedKwh;
          }
          // Use predicted cost from prediction model
          if (widget.prediction!.predictedCost > 0) {
            predictionCostDataMap[i] = widget.prediction!.predictedCost;
          }
        }
      }

      lineBarsData.add(
        LineChartBarData(
          spots: predictionSpots,
          isCurved: true,
          color: AppColor.accentRed.withAlpha((0.78 * 255).toInt()),
          barWidth: 3,
          dashArray: [5, 5],
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              if (index == predictionSpots.length - 1) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: AppColor.accentRed,
                  strokeWidth: 2,
                  strokeColor: chartColors.surfaceColor,
                );
              }
              return FlDotCirclePainter(radius: 0);
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    // Set maxY with proper padding to prevent overlap
    final maxY = maxKwh * 1.3;

    // Calculate the number of x-axis points
    final maxX =
        widget.prediction != null
            ? recentMonths.length.toDouble()
            : (recentMonths.length - 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend for appliances
        if (applianceMetadata.isNotEmpty) ...[
          _buildLegend(context, applianceMetadata, chartColors),
          SizedBox(height: Insets.sm),
        ],
        // Chart
        SizedBox(
          height: 250,
          child: Padding(
            padding: EdgeInsets.only(right: Insets.md, top: Insets.sm),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: chartColors.gridLineColor,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < recentMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _formatMonthLabel(recentMonths[idx]),
                              style: ResponsiveText.caption(
                                context,
                              ).copyWith(color: chartColors.textColor),
                            ),
                          );
                        }
                        if (widget.prediction != null &&
                            idx == recentMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Predicted',
                              style: ResponsiveText.caption(context).copyWith(
                                color: AppColor.accentRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 5,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: ResponsiveText.caption(
                            context,
                          ).copyWith(color: chartColors.textColor),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: chartColors.borderColor, width: 1),
                ),
                lineBarsData: lineBarsData,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final monthIndex = spot.x.toInt();
                        final isPrediction =
                            widget.prediction != null &&
                            monthIndex == recentMonths.length;

                        // Find which appliance this spot belongs to
                        String applianceName = 'Total';
                        double cost = 0.0;
                        double kwh = spot.y;

                        if (!isPrediction && monthIndex < recentMonths.length) {
                          // Find appliance data for this spot
                          for (final entry in applianceMetadata.entries) {
                            final monthData =
                                entry.value['monthData']
                                    as Map<int, Map<String, double>>;
                            if (monthData.containsKey(monthIndex)) {
                              final data = monthData[monthIndex]!;
                              if ((data['kwh'] ?? 0.0) == kwh) {
                                applianceName = _formatApplianceName(entry.key);
                                cost = data['cost'] ?? 0.0;
                                break;
                              }
                            }
                          }
                          // If not found, use aggregated cost
                          if (cost == 0.0) {
                            cost = costDataMap[monthIndex] ?? 0.0;
                          }
                        } else if (isPrediction) {
                          cost = predictionCostDataMap[monthIndex] ?? 0.0;
                          applianceName = 'Predicted Total';
                        }

                        final costText =
                            cost > 0 ? '\n₱${cost.toStringAsFixed(2)}' : '';

                        return LineTooltipItem(
                          '$applianceName\n${kwh.toStringAsFixed(2)} kWh$costText',
                          ResponsiveText.label(context).copyWith(
                            color: chartColors.tooltipTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                    getTooltipColor: (spots) {
                      return chartColors.tooltipBackgroundColor;
                    },
                  ),
                ),
                clipData: const FlClipData.all(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(
    BuildContext context,
    Map<String, Map<String, dynamic>> applianceMetadata,
    _PredictionChartColors chartColors,
  ) {
    final appliances = applianceMetadata.keys.toList();
    appliances.sort();

    final legendItems = <Widget>[];
    for (final appliance in appliances) {
      final metadata = applianceMetadata[appliance]!;
      final color = metadata['color'] as Color;
      legendItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: chartColors.surfaceColor, width: 2),
              ),
            ),
            SizedBox(width: Insets.xm),
            Text(
              _formatApplianceName(appliance),
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: chartColors.textColor, fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (widget.prediction != null) {
      legendItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColor.accentRed,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            SizedBox(width: Insets.xm),
            Text(
              'Predicted',
              style: ResponsiveText.caption(context).copyWith(
                color: AppColor.accentRed,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: Insets.md,
      runSpacing: Insets.sm,
      children: legendItems,
    );
  }

  String _formatMonthLabel(String monthStr) {
    try {
      // Try to parse and format the month string
      final parts = monthStr.split(' ');
      if (parts.isNotEmpty) {
        return parts[0]; // Return first part (month name)
      }
      return monthStr;
    } catch (_) {
      return monthStr;
    }
  }

  String _formatApplianceName(String applianceId) {
    // First check if there's a custom alias/display name
    if (_applianceAliases.containsKey(applianceId) &&
        _applianceAliases[applianceId]!.isNotEmpty) {
      return _applianceAliases[applianceId]!;
    }

    // Fallback to default formatting
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

  Widget _buildBarChart(
    BuildContext context,
    List<PredictiveDataModel> dataset,
  ) {
    final chartColors = _PredictionChartColors.fromContext(context);
    final applianceGroups = <String, List<PredictiveDataModel>>{};

    for (final data in dataset) {
      applianceGroups.putIfAbsent(data.appliance, () => []).add(data);
    }

    // Calculate totals for each appliance
    final applianceTotals = <String, Map<String, double>>{};
    for (final entry in applianceGroups.entries) {
      final totalCost = entry.value
          .map((d) => d.cost)
          .fold(0.0, (sum, cost) => sum + cost);
      final totalKwh = entry.value
          .map((d) => d.energyKwh)
          .fold(0.0, (sum, kwh) => sum + kwh);
      applianceTotals[entry.key] = {'cost': totalCost, 'kwh': totalKwh};
    }

    // Sort appliances by cost (descending) for better visualization
    final appliances = applianceTotals.keys.toList();
    appliances.sort(
      (a, b) => (applianceTotals[b]!['cost'] ?? 0.0).compareTo(
        applianceTotals[a]!['cost'] ?? 0.0,
      ),
    );

    final bars = <BarChartGroupData>[];
    final totalCost = applianceTotals.values.fold(
      0.0,
      (sum, data) => sum + (data['cost'] ?? 0.0),
    );

    for (int i = 0; i < appliances.length; i++) {
      final appliance = appliances[i];
      final cost = applianceTotals[appliance]!['cost'] ?? 0.0;
      final percentage = totalCost > 0 ? (cost / totalCost * 100) : 0.0;

      // Use color based on cost percentage
      Color barColor;
      if (percentage > 30) {
        barColor = AppColor.accentRed;
      } else if (percentage > 15) {
        barColor = AppColor.mediumConsumption;
      } else {
        barColor =
            chartColors.applianceColors[i % chartColors.applianceColors.length];
      }

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: cost,
              color: barColor,
              width: 24,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: totalCost,
                color: chartColors.gridLineColor,
              ),
            ),
          ],
        ),
      );
    }

    final maxCost =
        bars.isNotEmpty
            ? bars
                .map((b) => b.barRods.first.toY)
                .reduce((a, b) => a > b ? a : b)
            : 100.0;
    final maxY = maxCost * 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary info
        Container(
          padding: EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: chartColors.surfaceColor.withAlpha((0.5 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Iconsax.info_circle,
                size: 16,
                color: chartColors.secondaryTextColor,
              ),
              SizedBox(width: Insets.xm),
              Expanded(
                child: Text(
                  'Total: ₱${totalCost.toStringAsFixed(2)} across ${appliances.length} appliances',
                  style: ResponsiveText.caption(context).copyWith(
                    color: chartColors.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Insets.sm),
        // Chart
        SizedBox(
          height: 250,
          child: Padding(
            padding: EdgeInsets.only(right: Insets.md, top: Insets.sm),
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: chartColors.gridLineColor,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 5,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₱${value.toStringAsFixed(0)}',
                          style: ResponsiveText.caption(context).copyWith(
                            color: chartColors.textColor,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: chartColors.borderColor, width: 1),
                ),
                barGroups: bars,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) {
                      return chartColors.tooltipBackgroundColor;
                    },
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final appliance = appliances[groupIndex];
                      final cost = rod.toY;
                      final kwh = applianceTotals[appliance]!['kwh'] ?? 0.0;
                      final percentage =
                          totalCost > 0 ? (cost / totalCost * 100) : 0.0;

                      return BarTooltipItem(
                        '${_formatApplianceName(appliance)}\n'
                        '₱${cost.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)\n'
                        '${kwh.toStringAsFixed(2)} kWh',
                        ResponsiveText.label(context).copyWith(
                          color: chartColors.tooltipTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateMaxValue(
    List<PredictiveDataModel> dataset, {
    required bool useCost,
  }) {
    if (dataset.isEmpty) return 100.0;

    if (useCost) {
      return dataset.map((d) => d.cost).reduce((a, b) => a > b ? a : b);
    } else {
      return dataset.map((d) => d.energyKwh).reduce((a, b) => a > b ? a : b);
    }
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ChartCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final chartColors = _PredictionChartColors.fromContext(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      margin: EdgeInsets.only(bottom: Insets.md),
      decoration: BoxDecoration(
        color: chartColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: chartColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: ResponsiveText.stat(context).copyWith(
                        color: chartColors.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                SizedBox(height: Insets.xm),
                Text(
                  subtitle!,
                  style: ResponsiveText.caption(context).copyWith(
                    color: chartColors.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: Insets.lg),
          child,
        ],
      ),
    );
  }
}
