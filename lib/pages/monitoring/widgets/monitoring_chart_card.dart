import 'dart:math' as math;

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

class _ChartColors {
  final Color primaryColor;
  final Color surfaceColor;
  final Color tooltipTextColor;
  final Color tooltipBackgroundColor;
  final Color horizontalLineColor;
  final Color gridLineColor;
  final Color dotColor;
  final Color dotStrokeColor;
  final Color areaGradientColor;
  final Color textColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color backgroundRodColor;

  _ChartColors({
    required this.primaryColor,
    required this.surfaceColor,
    required this.tooltipTextColor,
    required this.tooltipBackgroundColor,
    required this.horizontalLineColor,
    required this.gridLineColor,
    required this.dotColor,
    required this.dotStrokeColor,
    required this.areaGradientColor,
    required this.textColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.backgroundRodColor,
  });

  factory _ChartColors.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _ChartColors(
      primaryColor: isDark ? AppColor.accentGreen : AppColor.primary,
      surfaceColor: isDark ? AppColor.surfaceDark : AppColor.surface,
      tooltipTextColor: isDark ? AppColor.textPrimaryDark : Colors.white,
      tooltipBackgroundColor:
          isDark
              ? AppColor.primaryDark.withAlpha((0.9 * 255).toInt())
              : AppColor.primary.withAlpha((0.9 * 255).toInt()),
      horizontalLineColor:
          isDark
              ? AppColor.textSecondaryDark.withAlpha(110)
              : AppColor.disabled.withAlpha(90),
      gridLineColor:
          isDark
              ? AppColor.textSecondaryDark.withAlpha(80)
              : AppColor.disabled.withAlpha(60),
      dotColor: isDark ? AppColor.surfaceDark : AppColor.surface,
      dotStrokeColor: isDark ? AppColor.accentGreen : AppColor.primary,
      areaGradientColor:
          isDark
              ? AppColor.accentGreen.withAlpha((0.15 * 255).toInt())
              : AppColor.primary.withAlpha((0.12 * 255).toInt()),
      textColor: isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
      secondaryColor: AppColor.accentGreen,
      tertiaryColor:
          isDark ? AppColor.accentGreen.withAlpha(200) : AppColor.accentGreen,
      backgroundRodColor:
          isDark
              ? AppColor.textSecondaryDark.withAlpha(80)
              : AppColor.disabled.withAlpha(60),
    );
  }
}

class _MonitoringChartCardState extends State<MonitoringChartCard> {
  final TrendsService _trendsService = TrendsService();
  final MonitoringDatasetService _monitoringDatasetService =
      MonitoringDatasetService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  ChartMetric _selectedMetric = ChartMetric.kWh;
  final int _currentYear = DateTime.now().year;
  late final List<DateTime> _yearMonths;
  late DateTime _selectedDailyMonth;
  late DateTime _selectedDay;
  int _selectedDayNumber = DateTime.now().day;
  String? _selectedWeekMonthKey;
  String? _selectedWeekKey;
  String? _selectedMonthKey;
  List<Map<String, dynamic>>? _dailyDataCache;
  List<Map<String, dynamic>>? _weeklyDataCache;
  List<Map<String, dynamic>>? _monthlyDataCache;

  @override
  void initState() {
    super.initState();
    _yearMonths = List.generate(
      12,
      (index) => DateTime(_currentYear, index + 1, 1),
    );
    final now = DateTime.now();
    _selectedDailyMonth = _yearMonths[now.month - 1];
    final daysInSelectedMonth = DateUtils.getDaysInMonth(
      _selectedDailyMonth.year,
      _selectedDailyMonth.month,
    );
    _selectedDayNumber = math.min(now.day, daysInSelectedMonth);
    _selectedDay = DateTime(
      _selectedDailyMonth.year,
      _selectedDailyMonth.month,
      _selectedDayNumber,
    );
    _selectedWeekMonthKey =
        '${_selectedDailyMonth.year}-${_selectedDailyMonth.month.toString().padLeft(2, '0')}';
    _selectedMonthKey = _selectedWeekMonthKey;
  }

  @override
  Widget build(BuildContext context) {
    return _buildChartSection(context, widget.period);
  }

  Widget _buildChartSection(BuildContext context, String period) {
    switch (period) {
      case 'Day':
        return _ChartCard(
          title: 'Daily Energy Usage',
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
          title: 'Weekly Energy Usage',
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
          title: 'Monthly Energy Usage',
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
      future: _getDailyDataForSelectedMonth(),
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

        final allMonthData = snapshot.data!;

        // Filter to show only 7 days: 3 days before selected, selected day, 3 days after
        final chartData = _getSevenDayWindow(allMonthData, _selectedDay);

        // Compute summary for the selected day (if present)
        final String selectedKey = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDay);
        Map<String, dynamic>? selectedEntry;
        for (final item in allMonthData) {
          if (item['date'] == selectedKey) {
            selectedEntry = item;
            break;
          }
        }
        final double selectedKwh =
            (selectedEntry?['totalKwh'] ?? 0.0).toDouble();
        final double selectedCost =
            (selectedEntry?['totalCost'] ?? 0.0).toDouble();

        final spots = _buildSpots(chartData, _selectedMetric);
        final useCost = _selectedMetric == ChartMetric.cost;
        final maxY = _calculateMaxValue(chartData, useCost: useCost) * 1.2;

        final chartColors = _ChartColors.fromContext(context);

        final bool hasSelectedData = selectedEntry != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDailyMonthSelector(context),
            SizedBox(height: Insets.sm),
            _buildDailyDaySelector(context),
            SizedBox(height: Insets.sm),
            Text(
              'Selected day: ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
              style: ResponsiveText.caption(context),
            ),
            SizedBox(height: Insets.xm),
            Text(
              'Total: ${selectedKwh.toStringAsFixed(2)} kWh • ₱${selectedCost.toStringAsFixed(2)}',
              style: ResponsiveText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            if (!hasSelectedData)
              Padding(
                padding: EdgeInsets.only(top: Insets.sm),
                child: Text(
                  'No consumption data available for this day.',
                  style: ResponsiveText.caption(context),
                ),
              ),
            SizedBox(height: Insets.md),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: chartColors.horizontalLineColor,
                          strokeWidth: 1,
                        ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < chartData.length) {
                            final dateStr = chartData[idx]['date'] as String?;
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
                          return Text(
                            '',
                            style: ResponsiveText.caption(context),
                          );
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
                      color: chartColors.primaryColor,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: chartColors.areaGradientColor,
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: chartColors.dotColor,
                            strokeWidth: 2,
                            strokeColor: chartColors.dotStrokeColor,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor:
                          (spots) => chartColors.tooltipBackgroundColor,
                      getTooltipItems:
                          (touchedSpots) =>
                              touchedSpots.map((spot) {
                                final idx = spot.x.toInt();
                                if (idx >= 0 && idx < chartData.length) {
                                  final kwh = chartData[idx]['totalKwh'] ?? 0.0;
                                  final cost =
                                      chartData[idx]['totalCost'] ?? 0.0;
                                  return LineTooltipItem(
                                    '${kwh.toStringAsFixed(2)} kWh\n₱${cost.toStringAsFixed(2)}',
                                    ResponsiveText.body(context).copyWith(
                                      color: chartColors.tooltipTextColor,
                                    ),
                                  );
                                }
                                return LineTooltipItem(
                                  '',
                                  ResponsiveText.body(context).copyWith(
                                    color: chartColors.tooltipTextColor,
                                  ),
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
            ),
          ],
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

        final sortedMonthKeys =
            _yearMonths
                .map(
                  (month) =>
                      '${month.year}-${month.month.toString().padLeft(2, '0')}',
                )
                .toList();
        _selectedWeekMonthKey ??= sortedMonthKeys.last;
        if (!sortedMonthKeys.contains(_selectedWeekMonthKey)) {
          _selectedWeekMonthKey = sortedMonthKeys.last;
        }

        // Filter weeks for selected month (for chart + week dropdown)
        final List<Map<String, dynamic>> monthWeeks =
            _selectedWeekMonthKey == null
                ? data
                : data.where((item) {
                  final startDateStr = item['startDate'] as String?;
                  if (startDateStr == null) return false;
                  try {
                    final d = DateTime.parse(startDateStr);
                    final key =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}';
                    return key == _selectedWeekMonthKey;
                  } catch (_) {
                    return false;
                  }
                }).toList();

        // Ensure we have at least one week to show
        final effectiveWeeks = monthWeeks.isNotEmpty ? monthWeeks : data;
        if (effectiveWeeks.isEmpty) {
          return _buildEmptyChart('No weekly data available');
        }

        // Choose a selected week for summary (default to last in effective list)
        final validWeekKeys =
            effectiveWeeks
                .map((item) => item['week'] as String?)
                .whereType<String>()
                .toList();
        if (_selectedWeekKey == null ||
            !validWeekKeys.contains(_selectedWeekKey)) {
          _selectedWeekKey =
              validWeekKeys.isNotEmpty ? validWeekKeys.last : null;
        }

        Map<String, dynamic>? selectedWeek;
        for (final item in effectiveWeeks) {
          if (item['week'] == _selectedWeekKey) {
            selectedWeek = item;
            break;
          }
        }
        selectedWeek ??= effectiveWeeks.last;

        final double selectedWeekKwh =
            (selectedWeek['totalKwh'] ?? 0.0).toDouble();
        final double selectedWeekCost =
            (selectedWeek['totalCost'] ?? 0.0).toDouble();

        // Spots for chart use only weeks within selected month (or all if none)
        final spots = _buildSpots(effectiveWeeks, _selectedMetric);
        final useCost = _selectedMetric == ChartMetric.cost;
        final maxY = _calculateMaxValue(effectiveWeeks, useCost: useCost) * 1.2;

        final chartColors = _ChartColors.fromContext(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month + week filter row - responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 350;
                if (isSmallScreen) {
                  // Stack vertically on small screens
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sortedMonthKeys.isNotEmpty) ...[
                        Row(
                          children: [
                            Text('Month:', style: ResponsiveText.body(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _selectedWeekMonthKey,
                                isExpanded: true,
                                items:
                                    sortedMonthKeys
                                        .map(
                                          (key) => DropdownMenuItem<String>(
                                            value: key,
                                            child: Text(
                                              _formatMonthLabel(key),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedWeekMonthKey = value;
                                    _selectedWeekKey = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Insets.sm),
                      ],
                      if (effectiveWeeks.isNotEmpty) ...[
                        Row(
                          children: [
                            Text('Week:', style: ResponsiveText.body(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _selectedWeekKey,
                                isExpanded: true,
                                items: List.generate(effectiveWeeks.length, (
                                  index,
                                ) {
                                  final item = effectiveWeeks[index];
                                  final weekKey =
                                      item['week'] as String? ??
                                      'W${(index + 1).toString().padLeft(2, '0')}';
                                  final label = 'Week ${index + 1}';
                                  return DropdownMenuItem<String>(
                                    value: weekKey,
                                    child: Text(
                                      label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedWeekKey = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                } else {
                  // Horizontal layout on larger screens
                  return Row(
                    children: [
                      if (sortedMonthKeys.isNotEmpty) ...[
                        Text('Month:', style: ResponsiveText.body(context)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: DropdownButton<String>(
                            value: _selectedWeekMonthKey,
                            isExpanded: true,
                            items:
                                sortedMonthKeys
                                    .map(
                                      (key) => DropdownMenuItem<String>(
                                        value: key,
                                        child: Text(
                                          _formatMonthLabel(key),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedWeekMonthKey = value;
                                _selectedWeekKey = null;
                              });
                            },
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),
                      if (effectiveWeeks.isNotEmpty) ...[
                        Text('Week:', style: ResponsiveText.body(context)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: DropdownButton<String>(
                            value: _selectedWeekKey,
                            isExpanded: true,
                            items: List.generate(effectiveWeeks.length, (
                              index,
                            ) {
                              final item = effectiveWeeks[index];
                              final weekKey =
                                  item['week'] as String? ??
                                  'W${(index + 1).toString().padLeft(2, '0')}';
                              final label = 'Week ${index + 1}';
                              return DropdownMenuItem<String>(
                                value: weekKey,
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedWeekKey = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Selected week total: ${selectedWeekKwh.toStringAsFixed(2)} kWh • ₱${selectedWeekCost.toStringAsFixed(2)}',
              style: ResponsiveText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: chartColors.horizontalLineColor,
                          strokeWidth: 1,
                        ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < effectiveWeeks.length) {
                            final label = 'Week ${idx + 1}';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: ResponsiveText.caption(context),
                              ),
                            );
                          }
                          return Text(
                            '',
                            style: ResponsiveText.caption(context),
                          );
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
                      color: chartColors.primaryColor,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: chartColors.areaGradientColor,
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: chartColors.dotColor,
                            strokeWidth: 2,
                            strokeColor: chartColors.dotStrokeColor,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor:
                          (spots) => chartColors.tooltipBackgroundColor,
                      getTooltipItems:
                          (touchedSpots) =>
                              touchedSpots.map((spot) {
                                final idx = spot.x.toInt();
                                final kwh =
                                    effectiveWeeks[idx]['totalKwh'] ?? 0.0;
                                final cost =
                                    effectiveWeeks[idx]['totalCost'] ?? 0.0;
                                return LineTooltipItem(
                                  '${kwh.toStringAsFixed(2)} kWh\n₱${cost.toStringAsFixed(2)}',
                                  ResponsiveText.body(context).copyWith(
                                    color: chartColors.tooltipTextColor,
                                  ),
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
            ),
          ],
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

        final sortedMonthKeys =
            _yearMonths
                .map(
                  (month) =>
                      '${month.year}-${month.month.toString().padLeft(2, '0')}',
                )
                .toList();
        _selectedMonthKey ??= sortedMonthKeys.last;

        // Find selected month entry for summary
        Map<String, dynamic>? selectedMonth;
        if (_selectedMonthKey != null) {
          for (final item in data) {
            if (item['month'] == _selectedMonthKey) {
              selectedMonth = item;
              break;
            }
          }
        }
        selectedMonth ??= data.last;

        final double selectedMonthKwh =
            (selectedMonth['totalKwh'] ?? 0.0).toDouble();
        final double selectedMonthCost =
            (selectedMonth['totalCost'] ?? 0.0).toDouble();

        final chartColors = _ChartColors.fromContext(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector + summary
            Row(
              children: [
                if (sortedMonthKeys.isNotEmpty) ...[
                  Text('Month:', style: ResponsiveText.body(context)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedMonthKey,
                    items:
                        sortedMonthKeys
                            .map(
                              (key) => DropdownMenuItem<String>(
                                value: key,
                                child: Text(_formatMonthLabel(key)),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMonthKey = value;
                      });
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Selected month total: ${selectedMonthKwh.toStringAsFixed(2)} kWh • ₱${selectedMonthCost.toStringAsFixed(2)}',
              style: ResponsiveText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
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
                          return Text(
                            '',
                            style: ResponsiveText.caption(context),
                          );
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
                                    colors: [
                                      chartColors.secondaryColor,
                                      chartColors.tertiaryColor,
                                    ],
                                  )
                                  : null,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: chartColors.backgroundRodColor,
                          ),
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor:
                          (group) => chartColors.tooltipBackgroundColor,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        final kwh = (data[idx]['totalKwh'] ?? 0.0).toDouble();
                        final cost = (data[idx]['totalCost'] ?? 0.0).toDouble();
                        return BarTooltipItem(
                          '${kwh.toStringAsFixed(2)} kWh\n₱${cost.toStringAsFixed(2)}',
                          ResponsiveText.body(
                            context,
                          ).copyWith(color: chartColors.tooltipTextColor),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getDailyData() async {
    if (_dailyDataCache != null) return _dailyDataCache!;
    try {
      AppLogger.i('[MonitoringChartCard] Fetching daily trends for year...');
      final startDate = DateTime(_currentYear, 1, 1);
      final endDate = DateTime(_currentYear, 12, 31);

      // Try TrendsService first
      final trendsData = await _trendsService.getDailyTrends(
        startDate,
        endDate,
      );
      AppLogger.i(
        '[MonitoringChartCard] Daily trends from TrendsService: ${trendsData.length} records',
      );

      if (trendsData.isNotEmpty) {
        _dailyDataCache = trendsData;
        return _dailyDataCache!;
      }

      // Fallback: try current day usage
      AppLogger.w(
        '[MonitoringChartCard] No daily trends found, trying Realtime DB fallback...',
      );
      final todayUsage = await _getTodayUsageFromRealtimeDB();
      if (todayUsage['totalKwh'] != null &&
          (todayUsage['totalKwh'] as double) > 0) {
        final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _dailyDataCache = [
          {
            'date': todayKey,
            'totalKwh': todayUsage['totalKwh'] ?? 0.0,
            'totalCost': todayUsage['totalCost'] ?? 0.0,
            'totalUsageTime': todayUsage['totalUsageTime'] ?? 0,
            'timestamp': DateTime.now(),
          },
        ];
        return _dailyDataCache!;
      }

      _dailyDataCache = [];
      return _dailyDataCache!;
    } catch (e, stackTrace) {
      AppLogger.e(
        '[MonitoringChartCard] Error fetching daily data: $e',
        e,
        stackTrace,
      );
      _dailyDataCache = [];
      return _dailyDataCache!;
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
    if (_weeklyDataCache != null) return _weeklyDataCache!;
    try {
      AppLogger.i(
        '[MonitoringChartCard] Building weekly buckets from daily data...',
      );
      final dailyData = await _getDailyData();
      final List<Map<String, dynamic>> buckets = [];

      for (int month = 1; month <= 12; month++) {
        final monthKey = '${_currentYear}-${month.toString().padLeft(2, '0')}';
        final daysInMonth = DateUtils.getDaysInMonth(_currentYear, month);
        final totalWeeks = ((daysInMonth - 1) / 7).floor() + 1;
        for (int week = 0; week < totalWeeks; week++) {
          final startDay = week * 7 + 1;
          final endDay = math.min(startDay + 6, daysInMonth);
          final startDate = DateTime(_currentYear, month, startDay);
          final endDate = DateTime(_currentYear, month, endDay);
          buckets.add({
            'monthKey': monthKey,
            'week': '$monthKey-W${week + 1}',
            'weekNumber': week + 1,
            'startDate': DateFormat('yyyy-MM-dd').format(startDate),
            'endDate': DateFormat('yyyy-MM-dd').format(endDate),
            'totalKwh': 0.0,
            'totalCost': 0.0,
          });
        }
      }

      // Map for quick lookup
      final Map<String, Map<String, dynamic>> bucketMap = {
        for (final bucket in buckets) bucket['week'] as String: bucket,
      };

      for (final entry in dailyData) {
        final dateStr = entry['date'] as String?;
        if (dateStr == null) continue;
        try {
          final date = DateTime.parse(dateStr);
          if (date.year != _currentYear) continue;
          final monthKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';
          final weekNumber = ((date.day - 1) / 7).floor() + 1;
          final bucketKey = '$monthKey-W$weekNumber';
          final bucket = bucketMap[bucketKey];
          if (bucket != null) {
            bucket['totalKwh'] =
                (bucket['totalKwh'] as double) +
                ((entry['totalKwh'] ?? 0.0) as num).toDouble();
            bucket['totalCost'] =
                (bucket['totalCost'] as double) +
                ((entry['totalCost'] ?? 0.0) as num).toDouble();
          }
        } catch (_) {
          continue;
        }
      }

      _weeklyDataCache = buckets;
      return _weeklyDataCache!;
    } catch (e, stackTrace) {
      AppLogger.e(
        '[MonitoringChartCard] Error building weekly data: $e',
        e,
        stackTrace,
      );
      _weeklyDataCache = [];
      return _weeklyDataCache!;
    }
  }

  Future<List<Map<String, dynamic>>> _getMonthlyData() async {
    if (_monthlyDataCache != null) return _monthlyDataCache!;
    try {
      List<Map<String, dynamic>> source = [];
      bool hasSource = false;

      try {
        final datasetData =
            await _monitoringDatasetService.getMonthlyDataForCharts();
        AppLogger.i(
          '[MonitoringChartCard] Monthly data from dataset reference: ${datasetData.length} records',
        );
        if (datasetData.isNotEmpty) {
          source = datasetData;
          hasSource = true;
        } else {
          AppLogger.w(
            '[MonitoringChartCard] Dataset reference empty, attempting update...',
          );
          final updated =
              await _monitoringDatasetService.updateDatasetReference();
          if (updated) {
            final updatedData =
                await _monitoringDatasetService.getMonthlyDataForCharts();
            if (updatedData.isNotEmpty) {
              source = updatedData;
              hasSource = true;
            }
          }
        }
      } catch (e) {
        AppLogger.w(
          '[MonitoringChartCard] Error fetching dataset reference: $e',
        );
      }

      if (!hasSource) {
        AppLogger.i(
          '[MonitoringChartCard] Falling back to TrendsService for monthly data...',
        );
        final startDate = DateTime(_currentYear, 1, 1);
        final endDate = DateTime(_currentYear, 12, 31);
        final trendsData = await _trendsService.getMonthlyTrends(
          startDate,
          endDate,
        );
        if (trendsData.isNotEmpty) {
          source = trendsData;
          hasSource = true;
        }
      }

      if (!hasSource) {
        AppLogger.w(
          '[MonitoringChartCard] Aggregating monthly data from daily cache...',
        );
        final dailyData = await _getDailyData();
        source = _aggregateDailyToMonthly(dailyData);
      }

      final Map<String, Map<String, dynamic>> sourceMap = {};
      for (final entry in source) {
        final monthKey = entry['month'] as String?;
        if (monthKey == null) continue;
        sourceMap[monthKey] = entry;
      }

      final List<Map<String, dynamic>> months = [];
      for (int month = 1; month <= 12; month++) {
        final monthKey = '${_currentYear}-${month.toString().padLeft(2, '0')}';
        final existing = sourceMap[monthKey];
        months.add({
          'month': monthKey,
          'totalKwh': (existing?['totalKwh'] ?? 0.0).toDouble(),
          'totalCost': (existing?['totalCost'] ?? 0.0).toDouble(),
        });
      }

      _monthlyDataCache = months;
      return _monthlyDataCache!;
    } catch (e, stackTrace) {
      AppLogger.e(
        '[MonitoringChartCard] Error fetching monthly data: $e',
        e,
        stackTrace,
      );
      _monthlyDataCache =
          _yearMonths
              .map(
                (month) => {
                  'month':
                      '${month.year}-${month.month.toString().padLeft(2, '0')}',
                  'totalKwh': 0.0,
                  'totalCost': 0.0,
                },
              )
              .toList();
      return _monthlyDataCache!;
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

  /// Get daily data filtered for the selected month only
  Future<List<Map<String, dynamic>>> _getDailyDataForSelectedMonth() async {
    try {
      final allData = await _getDailyData();

      // Filter to only include data from the selected month
      final String selectedMonthKey = DateFormat(
        'yyyy-MM',
      ).format(_selectedDailyMonth);
      final List<Map<String, dynamic>> monthData =
          allData.where((item) {
            final dateStr = item['date'] as String?;
            if (dateStr == null) return false;
            try {
              final d = DateTime.parse(dateStr);
              return DateFormat('yyyy-MM').format(d) == selectedMonthKey;
            } catch (_) {
              return false;
            }
          }).toList();

      // Generate all days for the selected month, even if no data
      final int daysInMonth = DateUtils.getDaysInMonth(
        _selectedDailyMonth.year,
        _selectedDailyMonth.month,
      );
      final List<Map<String, dynamic>> fullMonthData = List.generate(
        daysInMonth,
        (index) {
          final day = index + 1;
          final date = DateTime(
            _selectedDailyMonth.year,
            _selectedDailyMonth.month,
            day,
          );
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final existingData = monthData.firstWhere(
            (item) => item['date'] == dateKey,
            orElse:
                () => {
                  'date': dateKey,
                  'totalKwh': 0.0,
                  'totalCost': 0.0,
                  'totalUsageTime': 0,
                  'timestamp': date,
                },
          );
          return existingData;
        },
      );

      return fullMonthData;
    } catch (e, stackTrace) {
      AppLogger.e(
        '[MonitoringChartCard] Error fetching daily data for selected month: $e',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// Get 7-day window around the selected date (3 days before, selected day, 3 days after)
  List<Map<String, dynamic>> _getSevenDayWindow(
    List<Map<String, dynamic>> allMonthData,
    DateTime selectedDay,
  ) {
    final List<Map<String, dynamic>> window = [];

    // Find the index of the selected day in the month data
    final String selectedKey = DateFormat('yyyy-MM-dd').format(selectedDay);
    int selectedIndex = -1;
    for (int i = 0; i < allMonthData.length; i++) {
      if (allMonthData[i]['date'] == selectedKey) {
        selectedIndex = i;
        break;
      }
    }

    if (selectedIndex == -1) {
      // Selected day not found, create a 7-day window ending at selected day
      final int selectedDayNumber = selectedDay.day;
      final int startDay = math.max(1, selectedDayNumber - 6);
      final int endDay = selectedDayNumber;

      for (int day = startDay; day <= endDay; day++) {
        final date = DateTime(selectedDay.year, selectedDay.month, day);
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final existingData = allMonthData.firstWhere(
          (item) => item['date'] == dateKey,
          orElse:
              () => {
                'date': dateKey,
                'totalKwh': 0.0,
                'totalCost': 0.0,
                'totalUsageTime': 0,
                'timestamp': date,
              },
        );
        window.add(existingData);
      }
    } else {
      // Start from 3 days before selected day, or day 1 of month if earlier
      final int startIndex = math.max(0, selectedIndex - 3);
      // End at 3 days after selected day, or last day of month if later
      final int endIndex = math.min(allMonthData.length - 1, selectedIndex + 3);

      // Extract the 7-day window (or less if at month boundaries)
      for (int i = startIndex; i <= endIndex; i++) {
        window.add(allMonthData[i]);
      }

      // If we have less than 7 days, pad from the other side
      while (window.length < 7 && window.length < allMonthData.length) {
        if (startIndex > 0) {
          // Add from before
          window.insert(0, allMonthData[startIndex - 1]);
        } else if (endIndex < allMonthData.length - 1) {
          // Add from after
          window.add(allMonthData[endIndex + 1]);
        } else {
          break;
        }
      }
    }

    return window;
  }

  String _formatMonthLabel(String monthKey) {
    // monthKey is expected to be yyyy-MM
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final dt = DateTime(year, month, 1);
      return DateFormat('MMMM yyyy').format(dt); // e.g. December 2025
    } catch (_) {
      return monthKey;
    }
  }

  Widget _buildDailyMonthSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(bottom: Insets.xm),
      child: Row(
        children:
            _yearMonths.map((month) {
              final isSelected = month.month == _selectedDailyMonth.month;
              final label = DateFormat('MMM').format(month);
              return Padding(
                padding: EdgeInsets.only(right: Insets.sm),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDailyMonth = month;
                      final daysInMonth = DateUtils.getDaysInMonth(
                        month.year,
                        month.month,
                      );
                      _selectedDayNumber = math.min(
                        _selectedDayNumber,
                        daysInMonth,
                      );
                      _selectedDay = DateTime(
                        month.year,
                        month.month,
                        _selectedDayNumber,
                      );
                      _selectedWeekMonthKey =
                          '${month.year}-${month.month.toString().padLeft(2, '0')}';
                      _selectedMonthKey = _selectedWeekMonthKey;
                      // Clear cache to force refresh when month changes
                      _dailyDataCache = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.sm,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.outlineVariant.withAlpha(120),
                      ),
                    ),
                    child: Text(
                      label,
                      style: ResponsiveText.body(context).copyWith(
                        color:
                            isSelected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildDailyDaySelector(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedDailyMonth.year,
      _selectedDailyMonth.month,
    );
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(vertical: Insets.xm),
        itemCount: daysInMonth,
        separatorBuilder: (_, __) => SizedBox(width: Insets.xm),
        itemBuilder: (context, index) {
          final day = index + 1;
          final isSelected = day == _selectedDayNumber;
          return GestureDetector(
            onTap: () {
              if (isSelected) return;
              setState(() {
                _selectedDayNumber = day;
                _selectedDay = DateTime(
                  _selectedDailyMonth.year,
                  _selectedDailyMonth.month,
                  _selectedDayNumber,
                );
              });
            },
            child: Container(
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withAlpha(120),
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withAlpha(64),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Text(
                '$day',
                style: ResponsiveText.body(context).copyWith(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyChart([String? message]) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color iconColor =
        isDark ? AppColor.textSecondaryDark : AppColor.disabled;
    final Color primaryTextColor =
        isDark
            ? AppColor.textPrimaryDark.withAlpha(190)
            : AppColor.textPrimary.withAlpha(210);
    final Color secondaryTextColor =
        isDark
            ? AppColor.textSecondaryDark.withAlpha(180)
            : AppColor.textSecondary.withAlpha(200);

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
    final isDark = theme.brightness == Brightness.dark;
    final Color iconColor = AppColor.accentRed;
    final Color headlineColor = AppColor.accentRed;
    final Color messageColor =
        isDark ? AppColor.textSecondaryDark : AppColor.textSecondary;

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
    final isDark = theme.brightness == Brightness.dark;
    final Color cardColor = isDark ? AppColor.surfaceDark : AppColor.surface;
    final Color shadowColor =
        isDark ? Colors.black.withAlpha(90) : Colors.black.withAlpha(45);

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
    final isDark = theme.brightness == Brightness.dark;
    final Color borderColor =
        isDark
            ? AppColor.textSecondaryDark.withAlpha(80)
            : AppColor.disabled.withAlpha(60);
    final Color backgroundColor =
        isDark
            ? AppColor.primaryDark.withAlpha(110)
            : AppColor.surface.withAlpha(240);

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
    final isDark = theme.brightness == Brightness.dark;
    final Color selectedColor =
        isDark ? AppColor.accentGreen : AppColor.primary;
    final Color selectedTextColor = Colors.white;
    final Color unselectedTextColor =
        isDark ? AppColor.textSecondaryDark : AppColor.textSecondary;

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
