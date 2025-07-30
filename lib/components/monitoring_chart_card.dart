import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:intl/intl.dart';

class MonitoringChartCard extends StatelessWidget {
  final String period;
  const MonitoringChartCard({Key? key, required this.period}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildChartSection(context, period);
  }

  Widget _buildChartSection(BuildContext context, String period) {
    switch (period) {
      case 'Day':
        return _ChartCard(
          title: "Today's Usage",
          child: _buildLineChart(context, label: 'kWh'),
        );
      case 'Week':
        return _ChartCard(
          title: 'Weekly Usage Trend',
          child: _buildLineChart(context, label: 'kWh'),
        );
      case 'Month':
        return _ChartCard(
          title: 'Monthly Consumption',
          child: _buildBarChart(context, by: 'month'),
        );
      case 'Year':
        return _ChartCard(
          title: 'Yearly Consumption',
          child: _buildBarChart(context, by: 'year'),
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildLineChart(BuildContext context, {String label = ''}) {
    final now = DateTime.now();
    final usageSpots = [
      FlSpot(0, 5.2),
      FlSpot(1, 6.1),
      FlSpot(2, 5.8),
      FlSpot(3, 7.2),
      FlSpot(4, 6.5),
      FlSpot(5, 6.9),
      FlSpot(6, 7.5),
    ];
    final double maxY = 8.0; // Consistent Y-axis max
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine:
                (value) => FlLine(
                  color: AppColor.disabled.withAlpha((0.2 * 255).toInt()),
                  strokeWidth: 1,
                ),
            getDrawingVerticalLine:
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
                getTitlesWidget: (value, _) {
                  final date = now.subtract(Duration(days: 6 - value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('E').format(date),
                      style: ResponsiveText.caption(context),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                reservedSize: 35,
                getTitlesWidget: (value, _) {
                  return Text(
                    '${value.toInt()}',
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
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: usageSpots,
              isCurved: true,
              color: AppColor.primary,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: AppColor.primary.withAlpha((0.1 * 255).toInt()),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppColor.background,
                    strokeWidth: 2,
                    strokeColor: AppColor.primary,
                  );
                },
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spots) => AppColor.primary.withAlpha(230),
              getTooltipItems:
                  (touchedSpots) =>
                      touchedSpots
                          .map(
                            (spot) => LineTooltipItem(
                              '${spot.y.toStringAsFixed(2)} kWh',
                              ResponsiveText.body(
                                context,
                              ).copyWith(color: Colors.white),
                            ),
                          )
                          .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, {String by = 'month'}) {
    final double maxY =
        by == 'year'
            ? 2500
            : by == 'month'
            ? 250
            : 8.0;
    if (by == 'month') {
      final List<double> monthlyData = [
        180.5,
        195.2,
        170.8,
        200.1,
        210.0,
        205.5,
        198.0,
        215.3,
        220.1,
        210.7,
        205.0,
        199.8,
      ];
      final List<String> monthLabels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final int currentMonth = DateTime.now().month - 1;
      return SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        idx >= 0 && idx < monthLabels.length
                            ? monthLabels[idx]
                            : '',
                        style: ResponsiveText.caption(context),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 50,
                  reservedSize: 35,
                  getTitlesWidget: (value, _) {
                    return Text(
                      '${value.toInt()}',
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
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              monthlyData.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: monthlyData[i],
                    width: 16,
                    color:
                        i == currentMonth
                            ? null
                            : _getConsumptionColor(monthlyData[i]),
                    gradient:
                        i == currentMonth
                            ? LinearGradient(
                              colors: [
                                AppColor.accentGreen,
                                AppColor.lowConsumption,
                              ],
                            )
                            : null,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
                showingTooltipIndicators: i == currentMonth ? [0] : [],
              ),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => AppColor.primary.withAlpha(230),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${monthlyData[group.x.toInt()].toStringAsFixed(1)} kWh',
                    ResponsiveText.body(context).copyWith(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      );
    } else if (by == 'year') {
      final List<double> yearlyData = [2100.0, 2200.5, 2050.3, 2300.7, 2250.2];
      final int currentYear = DateTime.now().year;
      final List<String> yearLabels = List.generate(
        5,
        (i) => (currentYear - 4 + i).toString(),
      );
      final int thisYearIdx = 4;
      return SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        idx >= 0 && idx < yearLabels.length
                            ? yearLabels[idx]
                            : '',
                        style: ResponsiveText.caption(context),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 200,
                  reservedSize: 35,
                  getTitlesWidget: (value, _) {
                    return Text(
                      '${value.toInt()}',
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
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              yearlyData.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: yearlyData[i],
                    width: 16,
                    color:
                        i == thisYearIdx
                            ? null
                            : _getConsumptionColor(yearlyData[i]),
                    gradient:
                        i == thisYearIdx
                            ? LinearGradient(
                              colors: [
                                AppColor.accentGreen,
                                AppColor.lowConsumption,
                              ],
                            )
                            : null,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
                showingTooltipIndicators: i == thisYearIdx ? [0] : [],
              ),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => AppColor.primary.withAlpha(230),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${yearlyData[group.x.toInt()].toStringAsFixed(1)} kWh',
                    ResponsiveText.body(context).copyWith(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      );
    } else {
      // fallback to week (default)
      final now = DateTime.now();
      final meterData = [5.2, 6.1, 5.8, 7.2, 6.5, 6.9, 7.5];
      return SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final date = now.subtract(
                      Duration(days: 6 - value.toInt()),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('E').format(date),
                        style: ResponsiveText.caption(context),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2,
                  reservedSize: 35,
                  getTitlesWidget: (value, _) {
                    return Text(
                      '${value.toInt()}',
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
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              meterData.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: meterData[i],
                    width: 16,
                    color: _getConsumptionColor(meterData[i]),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => AppColor.primary.withAlpha(230),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${meterData[group.x.toInt()].toStringAsFixed(1)} kWh',
                    ResponsiveText.body(context).copyWith(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }
  }

  Color _getConsumptionColor(double value) {
    if (value < 6.0) return AppColor.lowConsumption;
    if (value < 7.0) return AppColor.mediumConsumption;
    return AppColor.highConsumption;
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
      margin: EdgeInsets.only(bottom: Insets.sm),
      padding: EdgeInsets.all(Insets.lg),
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
          Text(title, style: ResponsiveText.stat(context)),
          SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}
