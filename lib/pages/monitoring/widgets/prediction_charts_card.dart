import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/predictive_dataset_service.dart';
import 'package:exercise_app/models/predictive_data_model.dart';
import 'package:exercise_app/models/prediction_result_model.dart';

class PredictionChartsCard extends StatelessWidget {
  final PredictionResultModel? prediction;

  const PredictionChartsCard({super.key, this.prediction});

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
          title: '3-Month kWh Trends by Appliance',
          child: _buildLineChart(context, datasetService.dataset),
        ),
        SizedBox(height: Insets.lg),

        // Cost Comparison Chart
        _ChartCard(
          title: 'Cost per Appliance Comparison',
          child: _buildBarChart(context, datasetService.dataset),
        ),
      ],
    );
  }

  Widget _buildLineChart(
    BuildContext context,
    List<PredictiveDataModel> dataset,
  ) {
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

    // Build spots for each appliance
    final applianceColors = [
      AppColor.accentGreen,
      AppColor.lowConsumption,
      AppColor.mediumConsumption,
      AppColor.primary,
      AppColor.accentRed,
    ];
    final lineBarsData = <LineChartBarData>[];

    int colorIndex = 0;
    // Store cost data for tooltips
    final costDataMap = <int, double>{};

    for (final entry in applianceGroups.entries) {
      final spots = <FlSpot>[];

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
        // Store cost for this month index (aggregate across all appliances)
        costDataMap[i] = (costDataMap[i] ?? 0.0) + totalCost;
      }

      if (spots.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: applianceColors[colorIndex % applianceColors.length],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        );
        colorIndex++;
      }
    }

    // Add prediction forecast line if available
    final predictionCostDataMap = <int, double>{};
    if (prediction != null && prediction!.applianceBreakdown != null) {
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
          predictionSpots.add(FlSpot(i.toDouble(), prediction!.predictedKwh));
          // Use predicted cost from prediction model
          if (prediction!.predictedCost > 0) {
            predictionCostDataMap[i] = prediction!.predictedCost;
          }
        }
      }

      lineBarsData.add(
        LineChartBarData(
          spots: predictionSpots,
          isCurved: true,
          color: AppColor.accentRed.withAlpha(200),
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
                  strokeColor: Colors.white,
                );
              }
              return FlDotCirclePainter(radius: 0);
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    final maxY = _calculateMaxValue(dataset, useCost: false) * 1.2;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine:
                (value) => FlLine(
                  color: AppColor.disabled.withAlpha((0.2 * 255).toInt()),
                  strokeWidth: 1,
                ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < recentMonths.length) {
                    return Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        recentMonths[idx].split(' ').first,
                        style: ResponsiveText.caption(context),
                      ),
                    );
                  }
                  if (prediction != null && idx == recentMonths.length) {
                    return Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Predicted',
                        style: ResponsiveText.caption(context).copyWith(
                          color: AppColor.accentRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxY / 5,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: ResponsiveText.caption(context),
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
          borderData: FlBorderData(show: true),
          lineBarsData: lineBarsData,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final monthIndex = spot.x.toInt();
                  // Get cost for this month (from either costDataMap or predictionCostDataMap)
                  final cost =
                      costDataMap[monthIndex] ??
                      predictionCostDataMap[monthIndex] ??
                      0.0;

                  // Check if this is a prediction spot (last point)
                  final isPrediction =
                      prediction != null && monthIndex == recentMonths.length;

                  final costText =
                      cost > 0 ? '\n₱${cost.toStringAsFixed(2)}' : '';

                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(2)} kWh$costText',
                    ResponsiveText.label(context).copyWith(
                      color: isPrediction ? AppColor.accentRed : Colors.white,
                    ),
                  );
                }).toList();
              },
              getTooltipColor: (spots) {
                // Default color, will be overridden by individual tooltip items
                return AppColor.primary.withAlpha(230);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(
    BuildContext context,
    List<PredictiveDataModel> dataset,
  ) {
    final applianceGroups = <String, List<PredictiveDataModel>>{};

    for (final data in dataset) {
      applianceGroups.putIfAbsent(data.appliance, () => []).add(data);
    }

    final bars = <BarChartGroupData>[];
    final appliances = applianceGroups.keys.toList();
    final applianceColors = [
      AppColor.accentGreen,
      AppColor.lowConsumption,
      AppColor.mediumConsumption,
      AppColor.primary,
      AppColor.accentRed,
    ];

    for (int i = 0; i < appliances.length; i++) {
      final appliance = appliances[i];
      final totalCost = applianceGroups[appliance]!
          .map((d) => d.cost)
          .fold(0.0, (sum, cost) => sum + cost);

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: totalCost,
              color: applianceColors[i % applianceColors.length],
              width: 20,
              borderRadius: BorderRadius.circular(4),
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
    final maxY = maxCost * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine:
                (value) => FlLine(
                  color: AppColor.disabled.withAlpha((0.2 * 255).toInt()),
                  strokeWidth: 1,
                ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < appliances.length) {
                    final appliance = appliances[idx];
                    return Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        appliance.length > 10
                            ? '${appliance.substring(0, 10)}...'
                            : appliance,
                        style: ResponsiveText.caption(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  return Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxY / 5,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '₱${value.toStringAsFixed(0)}',
                    style: ResponsiveText.caption(context),
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
          borderData: FlBorderData(show: true),
          barGroups: bars,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final appliance = appliances[groupIndex];
                final cost = rod.toY;
                return BarTooltipItem(
                  '$appliance\n₱${cost.toStringAsFixed(2)}',
                  ResponsiveText.label(context),
                );
              },
            ),
          ),
        ),
      ),
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
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xl),
      margin: EdgeInsets.only(bottom: Insets.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ResponsiveText.stat(context)),
          SizedBox(height: Insets.lg),
          child,
          SizedBox(height: Insets.md),
        ],
      ),
    );
  }
}
