import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:intl/intl.dart';
import 'package:exercise_app/services/trends_service.dart';
import 'package:exercise_app/services/monitoring_dataset_service.dart';
import 'package:exercise_app/utils/app_logger.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';

enum ChartMetric { kWh, cost }

class MonitoringChartCard extends StatefulWidget {
  final String period;
  const MonitoringChartCard({super.key, required this.period});

  @override
  State<MonitoringChartCard> createState() => _MonitoringChartCardState();
}

class _MonitoringChartCardState extends State<MonitoringChartCard> {
  final TrendsService _trendsService = TrendsService();
  final MonitoringDatasetService _monitoringDatasetService =
      MonitoringDatasetService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  ChartMetric _selectedMetric = ChartMetric.kWh;

  @override
  Widget build(BuildContext context) {
    return _buildChartSection(context, widget.period);
  }

  Widget _buildChartSection(BuildContext context, String period) {
    switch (period) {
      case 'Day':
        return _ChartCard(
          title: "Today's Usage",
          onMetricChanged: (metric) {
            setState(() {
              _selectedMetric = metric;
            });
          },
          selectedMetric: _selectedMetric,
          child: _buildDailyChart(context),
        );
      case 'Week':
        return _ChartCard(
          title: 'Weekly Usage Trend',
          onMetricChanged: (metric) {
            setState(() {
              _selectedMetric = metric;
            });
          },
          selectedMetric: _selectedMetric,
          child: _buildWeeklyChart(context),
        );
      case 'Month':
        return _ChartCard(
          title: 'Monthly Consumption',
          onMetricChanged: (metric) {
            setState(() {
              _selectedMetric = metric;
            });
          },
          selectedMetric: _selectedMetric,
          child: _buildMonthlyChart(context),
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildDailyChart(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getDailyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          AppLogger.e(
            '[MonitoringChartCard] Error in daily chart: ${snapshot.error}',
          );
          return _buildErrorChart(
            snapshot.error?.toString() ?? 'Unknown error',
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          AppLogger.w('[MonitoringChartCard] No daily data available');
          return _buildEmptyChart('No daily data available');
        }

        final data = snapshot.data!;
        final spots = _buildSpots(data, _selectedMetric);
        final useCost = _selectedMetric == ChartMetric.cost;
        final maxY = _calculateMaxValue(data, useCost: useCost) * 1.2;

        final theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        final Color primaryColor = theme.colorScheme.primary;
        final Color surfaceColor = theme.colorScheme.surface;
        final Color tooltipTextColor = theme.colorScheme.onPrimary;
        final Color horizontalLineColor = theme.colorScheme.outlineVariant
            .withAlpha(isDark ? 110 : 90);
        final Color tooltipBackgroundColor = primaryColor.withAlpha(
          (0.9 * 255).toInt(),
        );

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY / 5,
                getDrawingHorizontalLine:
                    (value) =>
                        FlLine(color: horizontalLineColor, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < data.length) {
                        final dateStr = data[idx]['date'] as String?;
                        if (dateStr != null) {
                          try {
                            final date = DateTime.parse(dateStr);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('M/d').format(date),
                                style: ResponsiveText.caption(context),
                              ),
                            );
                          } catch (e) {
                            return Text(
                              '',
                              style: ResponsiveText.caption(context),
                            );
                          }
                        }
                      }
                      return Text('', style: ResponsiveText.caption(context));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 5,
                    reservedSize: 40,
                    getTitlesWidget: (value, _) {
                      if (useCost) {
                        return Text(
                          '₱${value.toStringAsFixed(0)}',
                          style: ResponsiveText.caption(context),
                        );
                      }
                      return Text(
                        value.toStringAsFixed(1),
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
                  spots: spots,
                  isCurved: true,
                  color: primaryColor,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: primaryColor.withAlpha((0.12 * 255).toInt()),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: surfaceColor,
                        strokeWidth: 2,
                        strokeColor: primaryColor,
                      );
                    },
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spots) => tooltipBackgroundColor,
                  getTooltipItems:
                      (touchedSpots) =>
                          touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            final kwh = data[idx]['totalKwh'] ?? 0.0;
                            final cost = data[idx]['totalCost'] ?? 0.0;
                            return LineTooltipItem(
                              '${kwh.toStringAsFixed(2)} kWh\n₱${cost.toStringAsFixed(2)}',
                              ResponsiveText.body(
                                context,
                              ).copyWith(color: tooltipTextColor),
                            );
                          }).toList(),
                ),
              ),
              extraLinesData: ExtraLinesData(
                verticalLines: [],
                horizontalLines: [],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyChart(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getWeeklyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          AppLogger.e(
            '[MonitoringChartCard] Error in weekly chart: ${snapshot.error}',
          );
          return _buildErrorChart(
            snapshot.error?.toString() ?? 'Unknown error',
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          AppLogger.w('[MonitoringChartCard] No weekly data available');
          return _buildEmptyChart('No weekly data available');
        }

        final data = snapshot.data!;
        final spots = _buildSpots(data, _selectedMetric);
        final useCost = _selectedMetric == ChartMetric.cost;
        final maxY = _calculateMaxValue(data, useCost: useCost) * 1.2;

        final theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        final Color primaryColor = theme.colorScheme.primary;
        final Color surfaceColor = theme.colorScheme.surface;
        final Color tooltipTextColor = theme.colorScheme.onPrimary;
        final Color horizontalLineColor = theme.colorScheme.outlineVariant
            .withAlpha(isDark ? 110 : 90);
        final Color tooltipBackgroundColor = primaryColor.withAlpha(
          (0.9 * 255).toInt(),
        );

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY / 5,
                getDrawingHorizontalLine:
                    (value) =>
                        FlLine(color: horizontalLineColor, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < data.length) {
                        final week = data[idx]['week'] as String?;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            week != null ? 'W${week.split('-')[1]}' : '',
                            style: ResponsiveText.caption(context),
                          ),
                        );
                      }
                      return Text('', style: ResponsiveText.caption(context));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 5,
                    reservedSize: 40,
                    getTitlesWidget: (value, _) {
                      if (useCost) {
                        return Text(
                          '₱${value.toStringAsFixed(0)}',
                          style: ResponsiveText.caption(context),
                        );
                      }
                      return Text(
                        value.toStringAsFixed(1),
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
                  spots: spots,
                  isCurved: true,
                  color: primaryColor,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: primaryColor.withAlpha((0.12 * 255).toInt()),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: surfaceColor,
                        strokeWidth: 2,
                        strokeColor: primaryColor,
                      );
                    },
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spots) => tooltipBackgroundColor,
                  getTooltipItems:
                      (touchedSpots) =>
                          touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            final kwh = data[idx]['totalKwh'] ?? 0.0;
                            final cost = data[idx]['totalCost'] ?? 0.0;
                            return LineTooltipItem(
                              '${kwh.toStringAsFixed(2)} kWh\n₱${cost.toStringAsFixed(2)}',
                              ResponsiveText.body(
                                context,
                              ).copyWith(color: tooltipTextColor),
                            );
                          }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyChart(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getMonthlyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          AppLogger.e(
            '[MonitoringChartCard] Error in monthly chart: ${snapshot.error}',
          );
          return _buildErrorChart(
            snapshot.error?.toString() ?? 'Unknown error',
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          AppLogger.w('[MonitoringChartCard] No monthly data available');
          return _buildEmptyChart('No monthly data available');
        }

        final data = snapshot.data!;
        final useCost = _selectedMetric == ChartMetric.cost;
        final maxY = _calculateMaxValue(data, useCost: useCost) * 1.2;

        final theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        final Color primaryColor = theme.colorScheme.primary;
        final Color secondaryColor = theme.colorScheme.secondary;
        final Color tertiaryColor = theme.colorScheme.tertiary;
        final Color backgroundRodColor = theme.colorScheme.outlineVariant
            .withAlpha(isDark ? 80 : 60);
        final Color tooltipTextColor = theme.colorScheme.onPrimary;

        return SizedBox(
          height: 200,
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
                      if (idx >= 0 && idx < data.length) {
                        final monthStr = data[idx]['month'] as String?;
                        if (monthStr != null) {
                          try {
                            final parts = monthStr.split('-');
                            final monthInt =
                                int.tryParse(
                                  parts.length > 1 ? parts[1] : '0',
                                ) ??
                                0;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat(
                                  'MMM',
                                ).format(DateTime(2000, monthInt)),
                                style: ResponsiveText.caption(context),
                              ),
                            );
                          } catch (e) {
                            return Text(
                              '',
                              style: ResponsiveText.caption(context),
                            );
                          }
                        }
                      }
                      return Text('', style: ResponsiveText.caption(context));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 5,
                    reservedSize: 40,
                    getTitlesWidget: (value, _) {
                      if (useCost) {
                        return Text(
                          '₱${value.toStringAsFixed(0)}',
                          style: ResponsiveText.caption(context),
                        );
                      }
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
              borderData: FlBorderData(show: false),
              barGroups: List.generate(data.length, (i) {
                final value =
                    useCost
                        ? (data[i]['totalCost'] ?? 0.0).toDouble()
                        : (data[i]['totalKwh'] ?? 0.0).toDouble();
                final kwh = (data[i]['totalKwh'] ?? 0.0).toDouble();
                final isCurrentMonth = i == (data.length - 1);

                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      width: 20,
                      color:
                          isCurrentMonth
                              ? null
                              : _resolveConsumptionColor(context, kwh),
                      gradient:
                          isCurrentMonth
                              ? LinearGradient(
                                colors: [secondaryColor, tertiaryColor],
                              )
                              : null,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: backgroundRodColor,
                      ),
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor:
                      (group) => primaryColor.withAlpha((0.9 * 255).toInt()),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final idx = group.x.toInt();
                    final kwh = (data[idx]['totalKwh'] ?? 0.0).toDouble();
                    final cost = (data[idx]['totalCost'] ?? 0.0).toDouble();
                    return BarTooltipItem(
                      '${kwh.toStringAsFixed(2)} kWh\n₱${cost.toStringAsFixed(2)}',
                      ResponsiveText.body(
                        context,
                      ).copyWith(color: tooltipTextColor),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getDailyData() async {
    try {
      AppLogger.i('[MonitoringChartCard] Fetching daily trends...');
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));

      // Try TrendsService first
      final trendsData = await _trendsService.getDailyTrends(startDate, now);
      AppLogger.i(
        '[MonitoringChartCard] Daily trends from TrendsService: ${trendsData.length} records',
      );

      if (trendsData.isNotEmpty) {
        return trendsData;
      }

      // Fallback: Try to get today's usage from Realtime DB and create daily data
      AppLogger.w(
        '[MonitoringChartCard] No daily trends found, trying Realtime DB fallback...',
      );
      final todayUsage = await _getTodayUsageFromRealtimeDB();

      if (todayUsage['totalKwh'] != null &&
          (todayUsage['totalKwh'] as double) > 0) {
        final todayKey = DateFormat('yyyy-MM-dd').format(now);
        final dailyData = [
          {
            'date': todayKey,
            'totalKwh': todayUsage['totalKwh'] ?? 0.0,
            'totalCost': todayUsage['totalCost'] ?? 0.0,
            'totalUsageTime': todayUsage['totalUsageTime'] ?? 0,
            'timestamp': DateTime.now(),
          },
        ];
        AppLogger.i(
          '[MonitoringChartCard] Created daily data from Realtime DB: ${dailyData.length} record',
        );
        return dailyData;
      }

      AppLogger.w(
        '[MonitoringChartCard] No daily data available from any source',
      );
      return [];
    } catch (e, stackTrace) {
      AppLogger.e(
        '[MonitoringChartCard] Error fetching daily data: $e',
        e,
        stackTrace,
      );
      return [];
    }
  }

  Future<Map<String, dynamic>> _getTodayUsageFromRealtimeDB() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'totalKwh': 0.0, 'totalCost': 0.0, 'totalUsageTime': 0};
      }

      final snapshot = await _database.ref('users/$userId/todayUsage').get();
      if (!snapshot.exists || snapshot.value == null) {
        return {'totalKwh': 0.0, 'totalCost': 0.0, 'totalUsageTime': 0};
      }

      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      AppLogger.e(
        '[MonitoringChartCard] Error getting today usage from Realtime DB: $e',
      );
      return {'totalKwh': 0.0, 'totalCost': 0.0, 'totalUsageTime': 0};
    }
  }

  Future<List<Map<String, dynamic>>> _getWeeklyData() async {
    try {
      AppLogger.i('[MonitoringChartCard] Fetching weekly trends...');
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 42)); // ~6 weeks

      // Try TrendsService first
      final weeklyTrends = await _trendsService.getWeeklyTrends(startDate, now);
      AppLogger.i(
        '[MonitoringChartCard] Weekly trends from TrendsService: ${weeklyTrends.length} records',
      );

      if (weeklyTrends.isNotEmpty) {
        return weeklyTrends;
      }

      // Fallback: Aggregate from daily trends
      AppLogger.w(
        '[MonitoringChartCard] No weekly trends found, aggregating from daily trends...',
      );
      final dailyStartDate = now.subtract(const Duration(days: 42));
      final dailyTrends = await _trendsService.getDailyTrends(
        dailyStartDate,
        now,
      );

      if (dailyTrends.isNotEmpty) {
        final weeklyData = _aggregateDailyToWeekly(dailyTrends);
        AppLogger.i(
          '[MonitoringChartCard] Created weekly data from daily trends: ${weeklyData.length} records',
        );
        return weeklyData;
      }

      AppLogger.w(
        '[MonitoringChartCard] No weekly data available from any source',
      );
      return [];
    } catch (e, stackTrace) {
      AppLogger.e(
        '[MonitoringChartCard] Error fetching weekly data: $e',
        e,
        stackTrace,
      );
      return [];
    }
  }

  List<Map<String, dynamic>> _aggregateDailyToWeekly(
    List<Map<String, dynamic>> dailyTrends,
  ) {
    final Map<String, Map<String, dynamic>> weeklyMap = {};

    for (final daily in dailyTrends) {
      final dateStr = daily['date'] as String?;
      if (dateStr == null) continue;

      try {
        final date = DateTime.parse(dateStr);
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final weekKey = '${weekStart.year}-W${_getWeekNumber(weekStart)}';

        if (!weeklyMap.containsKey(weekKey)) {
          weeklyMap[weekKey] = {
            'week': weekKey,
            'startDate': DateFormat('yyyy-MM-dd').format(weekStart),
            'endDate': DateFormat(
              'yyyy-MM-dd',
            ).format(weekStart.add(const Duration(days: 6))),
            'totalKwh': 0.0,
            'totalCost': 0.0,
            'totalUsageTime': 0,
            'timestamp': weekStart,
          };
        }

        weeklyMap[weekKey]!['totalKwh'] =
            (weeklyMap[weekKey]!['totalKwh'] as double) +
            (daily['totalKwh'] ?? 0.0).toDouble();
        weeklyMap[weekKey]!['totalCost'] =
            (weeklyMap[weekKey]!['totalCost'] as double) +
            (daily['totalCost'] ?? 0.0).toDouble();
        weeklyMap[weekKey]!['totalUsageTime'] =
            (weeklyMap[weekKey]!['totalUsageTime'] as int) +
                    (daily['totalUsageTime'] ?? 0)
                as int;
      } catch (e) {
        AppLogger.w(
          '[MonitoringChartCard] Error parsing date in daily trends: $e',
        );
      }
    }

    return weeklyMap.values.toList()..sort((a, b) {
      final aDate = a['startDate'] as String;
      final bDate = b['startDate'] as String;
      return aDate.compareTo(bDate);
    });
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    final weekNumber =
        ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();
    return weekNumber;
  }

  Future<List<Map<String, dynamic>>> _getMonthlyData() async {
    try {
      AppLogger.i('[MonitoringChartCard] Fetching monthly trends...');

      // Try to get data from dataset reference first (cloud storage)
      try {
        final datasetData =
            await _monitoringDatasetService.getMonthlyDataForCharts();
        AppLogger.i(
          '[MonitoringChartCard] Monthly data from dataset reference: ${datasetData.length} records',
        );

        if (datasetData.isNotEmpty) {
          return datasetData;
        }

        // If dataset exists but is empty, try to force update
        AppLogger.w(
          '[MonitoringChartCard] Dataset reference is empty, attempting to update...',
        );
        final updated =
            await _monitoringDatasetService.updateDatasetReference();
        if (updated) {
          final updatedData =
              await _monitoringDatasetService.getMonthlyDataForCharts();
          if (updatedData.isNotEmpty) {
            AppLogger.i(
              '[MonitoringChartCard] Monthly data after update: ${updatedData.length} records',
            );
            return updatedData;
          }
        }
      } catch (e) {
        AppLogger.w(
          '[MonitoringChartCard] Error fetching from dataset reference: $e',
        );
      }

      // Fallback to TrendsService
      AppLogger.i(
        '[MonitoringChartCard] Falling back to TrendsService for monthly data...',
      );
      final now = DateTime.now();
      final startDate = DateTime(now.year - 1, 1, 1);
      final trendsData = await _trendsService.getMonthlyTrends(startDate, now);
      AppLogger.i(
        '[MonitoringChartCard] Monthly trends from TrendsService: ${trendsData.length} records',
      );

      if (trendsData.isNotEmpty) {
        return trendsData;
      }

      // Last resort: Try to aggregate from daily/weekly trends
      AppLogger.w(
        '[MonitoringChartCard] No monthly trends found, attempting to aggregate from daily trends...',
      );
      final dailyStartDate = DateTime(
        now.year,
        now.month - 2,
        1,
      ); // Last 3 months
      final dailyTrends = await _trendsService.getDailyTrends(
        dailyStartDate,
        now,
      );

      if (dailyTrends.isNotEmpty) {
        final monthlyData = _aggregateDailyToMonthly(dailyTrends);
        AppLogger.i(
          '[MonitoringChartCard] Created monthly data from daily trends: ${monthlyData.length} records',
        );
        return monthlyData;
      }

      AppLogger.w(
        '[MonitoringChartCard] No monthly data available from any source',
      );
      return [];
    } catch (e, stackTrace) {
      AppLogger.e(
        '[MonitoringChartCard] Error fetching monthly data: $e',
        e,
        stackTrace,
      );
      return [];
    }
  }

  List<Map<String, dynamic>> _aggregateDailyToMonthly(
    List<Map<String, dynamic>> dailyTrends,
  ) {
    final Map<String, Map<String, dynamic>> monthlyMap = {};

    for (final daily in dailyTrends) {
      final dateStr = daily['date'] as String?;
      if (dateStr == null) continue;

      try {
        final date = DateTime.parse(dateStr);
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';

        if (!monthlyMap.containsKey(monthKey)) {
          final firstDayOfMonth = DateTime(date.year, date.month, 1);
          final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
          monthlyMap[monthKey] = {
            'month': monthKey,
            'startDate': DateFormat('yyyy-MM-dd').format(firstDayOfMonth),
            'endDate': DateFormat('yyyy-MM-dd').format(lastDayOfMonth),
            'totalKwh': 0.0,
            'totalCost': 0.0,
            'totalUsageTime': 0,
            'timestamp': firstDayOfMonth,
          };
        }

        monthlyMap[monthKey]!['totalKwh'] =
            (monthlyMap[monthKey]!['totalKwh'] as double) +
            (daily['totalKwh'] ?? 0.0).toDouble();
        monthlyMap[monthKey]!['totalCost'] =
            (monthlyMap[monthKey]!['totalCost'] as double) +
            (daily['totalCost'] ?? 0.0).toDouble();
        monthlyMap[monthKey]!['totalUsageTime'] =
            (monthlyMap[monthKey]!['totalUsageTime'] as int) +
                    (daily['totalUsageTime'] ?? 0)
                as int;
      } catch (e) {
        AppLogger.w(
          '[MonitoringChartCard] Error parsing date in daily trends for monthly: $e',
        );
      }
    }

    return monthlyMap.values.toList()..sort((a, b) {
      final aMonth = a['month'] as String;
      final bMonth = b['month'] as String;
      return aMonth.compareTo(bMonth);
    });
  }

  List<FlSpot> _buildSpots(
    List<Map<String, dynamic>> data,
    ChartMetric metric,
  ) {
    return List.generate(data.length, (i) {
      final value =
          metric == ChartMetric.cost
              ? (data[i]['totalCost'] ?? 0.0).toDouble()
              : (data[i]['totalKwh'] ?? 0.0).toDouble();
      return FlSpot(i.toDouble(), value);
    });
  }

  double _calculateMaxValue(
    List<Map<String, dynamic>> data, {
    required bool useCost,
  }) {
    if (data.isEmpty) return 100.0;
    double max = 0.0;
    for (final item in data) {
      final value =
          useCost
              ? (item['totalCost'] ?? 0.0).toDouble()
              : (item['totalKwh'] ?? 0.0).toDouble();
      if (value > max) max = value;
    }
    return max > 0 ? max : 100.0;
  }

  Color _getConsumptionColor(double value) {
    // Adjust thresholds based on typical values
    if (value < 50.0) return AppColor.lowConsumption;
    if (value < 150.0) return AppColor.mediumConsumption;
    return AppColor.highConsumption;
  }

  Color _resolveConsumptionColor(BuildContext context, double value) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final base = _getConsumptionColor(value);
    return isDark ? base.withAlpha((0.85 * 255).toInt()) : base;
  }

  Widget _buildEmptyChart([String? message]) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color iconColor = theme.colorScheme.outline;
    final Color primaryTextColor = theme.colorScheme.onSurface.withAlpha(
      isDark ? 190 : 210,
    );
    final Color secondaryTextColor = theme.colorScheme.onSurfaceVariant
        .withAlpha(isDark ? 180 : 200);

    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.chart_2, color: iconColor, size: 32),
            SizedBox(height: Insets.sm),
            Text(
              message ?? 'No data available',
              style: ResponsiveText.body(
                context,
              ).copyWith(color: primaryTextColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Insets.xm),
            Text(
              'Data will appear as usage is recorded',
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorChart(String error) {
    final theme = Theme.of(context);
    final Color iconColor = theme.colorScheme.error;
    final Color headlineColor = theme.colorScheme.error;
    final Color messageColor = theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.info_circle, color: iconColor, size: 32),
            SizedBox(height: Insets.sm),
            Text(
              'Error loading data',
              style: ResponsiveText.body(
                context,
              ).copyWith(color: headlineColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Insets.xm),
            Text(
              error.length > 50 ? '${error.substring(0, 50)}...' : error,
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: messageColor),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final ChartMetric selectedMetric;
  final Function(ChartMetric) onMetricChanged;
  const _ChartCard({
    required this.title,
    required this.child,
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardColor = theme.colorScheme.surface;
    final Color shadowColor = theme.shadowColor.withAlpha(isDark ? 90 : 45);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: Insets.sm),
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: ResponsiveText.stat(context)),
              _buildMetricToggle(context),
            ],
          ),
          SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricToggle(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color borderColor = theme.colorScheme.outlineVariant.withAlpha(
      isDark ? 80 : 60,
    );
    final Color backgroundColor = theme.colorScheme.surfaceContainerHigh
        .withAlpha(isDark ? 110 : 150);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(context, 'kWh', ChartMetric.kWh),
          _buildToggleButton(context, 'Cost', ChartMetric.cost),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context,
    String label,
    ChartMetric metric,
  ) {
    final isSelected = selectedMetric == metric;
    final theme = Theme.of(context);
    final Color selectedColor = theme.colorScheme.primary;
    final Color selectedTextColor = theme.colorScheme.onPrimary;
    final Color unselectedTextColor = theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => onMetricChanged(metric),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: ResponsiveText.caption(context).copyWith(
            color: isSelected ? selectedTextColor : unselectedTextColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
