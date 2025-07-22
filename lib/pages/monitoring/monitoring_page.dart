import 'package:exercise_app/constants/constant.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
// Import your constants file
// import 'constants.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  String selectedPeriod = 'Week';
  final List<String> periods = ['Day', 'Week', 'Month', 'Year'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColor.backgroundDark : AppColor.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView(
            padding: Insets.allLg,
            children: [
              _buildTopStats(),

              const SizedBox(height: Insets.xl),
              // Status Overview Cards
              _buildStatusOverview(isDark),

              const SizedBox(height: Insets.xl),

              // Period Selector
              _buildPeriodSelector(isDark),

              const SizedBox(height: Insets.lg),

              // Real-time Usage Card
              _buildRealtimeUsageCard(isDark),

              const SizedBox(height: Insets.lg),

              // Energy Usage Chart
              _buildCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Energy Usage Trend',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color:
                                isDark
                                    ? AppColor.textPrimaryDark
                                    : AppColor.textPrimary,
                          ),
                        ),
                        _buildTrendIndicator(5.2, isDark),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Average: 6.3 kWh/day',
                      style: TextStyle(
                        color:
                            isDark
                                ? AppColor.textSecondaryDark
                                : AppColor.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    _buildLineChart(isDark),
                  ],
                ),
              ),

              const SizedBox(height: Insets.lg),

              // Volume Meter Readings
              _buildCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Consumption',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color:
                                isDark
                                    ? AppColor.textPrimaryDark
                                    : AppColor.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.sm,
                            vertical: Insets.xm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColor.lowConsumption.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Normal',
                            style: TextStyle(
                              color: AppColor.lowConsumption,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.lg),
                    _buildBarChart(isDark),
                  ],
                ),
              ),

              const SizedBox(height: Insets.lg),

              // Enhanced Predictions & Insights
              _buildPredictionInsights(isDark),

              const SizedBox(height: Insets.lg),

              // Efficiency Metrics
              _buildEfficiencyMetrics(isDark),

              const SizedBox(height: Insets.lg),

              // Quick Actions
              _buildQuickActions(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverview(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            icon: Icons.flash_on,
            title: 'Current Rate',
            value: '₱10.25',
            subtitle: 'per kWh',
            color: AppColor.accentGreen,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: _buildStatusCard(
            icon: Icons.trending_up,
            title: 'Today\'s Usage',
            value: '7.2',
            subtitle: 'kWh',
            color: AppColor.mediumConsumption,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: _buildStatusCard(
            icon: Icons.account_balance_wallet,
            title: 'Est. Cost',
            value: '₱73.80',
            subtitle: 'today',
            color: AppColor.primary,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: Insets.allMd,
      decoration: BoxDecoration(
        color: isDark ? AppColor.surfaceDark : AppColor.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: Insets.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color:
                  isDark ? AppColor.textSecondaryDark : AppColor.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color:
                  isDark ? AppColor.textSecondaryDark : AppColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    return Row(
      children: [
        Text(
          'Period: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  periods.map((period) {
                    final isSelected = period == selectedPeriod;
                    return GestureDetector(
                      onTap: () => setState(() => selectedPeriod = period),
                      child: Container(
                        margin: const EdgeInsets.only(right: Insets.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.md,
                          vertical: Insets.sm,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColor.primary
                                  : (isDark
                                      ? AppColor.surfaceDark
                                      : AppColor.background),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              isSelected
                                  ? null
                                  : Border.all(
                                    color:
                                        isDark
                                            ? AppColor.disabled
                                            : AppColor.disabled,
                                    width: 1,
                                  ),
                        ),
                        child: Text(
                          period,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColor.textSecondaryDark
                                        : AppColor.textSecondary),
                            fontSize: 12,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRealtimeUsageCard(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Real-time Usage',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color:
                      isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColor.accentGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.circle, color: AppColor.accentGreen, size: 8),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2.4 kW',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
                ),
              ),
              Icon(Iconsax.convertshape4, color: isDark? AppColor.textPrimaryDark.withAlpha(128): AppColor.textPrimary.withAlpha(128),),
              Text(
                '₱00.0000',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(double percentage, bool isDark) {
    final isPositive = percentage >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xm,
      ),
      decoration: BoxDecoration(
        color: (isPositive ? AppColor.accentRed : AppColor.accentGreen)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? AppColor.accentRed : AppColor.accentGreen,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            '${percentage.abs()}%',
            style: TextStyle(
              color: isPositive ? AppColor.accentRed : AppColor.accentGreen,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionInsights(bool isDark) {
    return Column(
      children: [
        _buildCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Prediction',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color:
                      isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
                ),
              ),
              const SizedBox(height: Insets.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projected Usage',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppColor.textSecondaryDark
                                    : AppColor.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '186 kWh',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark
                                    ? AppColor.textPrimaryDark
                                    : AppColor.textPrimary,
                          ),
                        ),
                        Text(
                          'vs 195 kWh last month',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColor.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColor.accentGreen.withOpacity(0.1),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: 0.68,
                              strokeWidth: 4,
                              backgroundColor: AppColor.disabled.withOpacity(
                                0.3,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColor.accentGreen,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '68%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColor.accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              LinearProgressIndicator(
                value: 0.68,
                backgroundColor:
                    isDark
                        ? AppColor.disabled.withOpacity(0.2)
                        : AppColor.disabled.withOpacity(0.3),
                color: AppColor.accentGreen,
                minHeight: 6,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                '22 days remaining in billing cycle',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      isDark
                          ? AppColor.textSecondaryDark
                          : AppColor.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEfficiencyMetrics(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                Icon(Icons.eco, color: AppColor.accentGreen, size: 24),
                const SizedBox(height: Insets.sm),
                Text(
                  'Efficiency Score',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppColor.textSecondaryDark
                            : AppColor.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '8.2/10',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColor.accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                Icon(
                  Icons.savings,
                  color: AppColor.mediumConsumption,
                  size: 24,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  'Savings This Month',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppColor.textSecondaryDark
                            : AppColor.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱92.50',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColor.mediumConsumption,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? AppColor.textPrimaryDark : AppColor.textPrimary,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Iconsax.bill,
                  label: 'View Bill',
                  onTap: () {},
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _buildActionButton(
                  icon: Iconsax.export,
                  label: 'Export Data',
                  onTap: () {},
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _buildActionButton(
                  icon: Iconsax.import,
                  label: 'Import Data',
                  onTap: () {},
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: Insets.allMd,
        decoration: BoxDecoration(
          color: isDark ? AppColor.backgroundDark : AppColor.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isDark
                    ? AppColor.disabled.withOpacity(0.2)
                    : AppColor.disabled.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  isDark ? AppColor.textSecondaryDark : AppColor.textSecondary,
              size: 20,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:
                    isDark
                        ? AppColor.textSecondaryDark
                        : AppColor.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: Insets.allLg,
      decoration: BoxDecoration(
        color: isDark ? AppColor.surfaceDark : AppColor.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLineChart(bool isDark) {
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

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine:
                (value) => FlLine(
                  color:
                      isDark
                          ? AppColor.disabled.withOpacity(0.1)
                          : AppColor.disabled.withOpacity(0.2),
                  strokeWidth: 1,
                ),
            getDrawingVerticalLine:
                (value) => FlLine(
                  color:
                      isDark
                          ? AppColor.disabled.withOpacity(0.1)
                          : AppColor.disabled.withOpacity(0.2),
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
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isDark
                                ? AppColor.textSecondaryDark
                                : AppColor.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 35,
                getTitlesWidget: (value, _) {
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isDark
                              ? AppColor.textSecondaryDark
                              : AppColor.textSecondary,
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
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: usageSpots,
              isCurved: true,
              color: AppColor.primary,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: AppColor.primary.withOpacity(0.1),
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
        ),
      ),
    );
  }

  Widget _buildBarChart(bool isDark) {
    final now = DateTime.now();
    final meterData = [5.2, 6.1, 5.8, 7.2, 6.5, 6.9, 7.5];

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
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
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isDark
                                ? AppColor.textSecondaryDark
                                : AppColor.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 35,
                getTitlesWidget: (value, _) {
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isDark
                              ? AppColor.textSecondaryDark
                              : AppColor.textSecondary,
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
        ),
      ),
    );
  }

  Color _getConsumptionColor(double value) {
    if (value < 6.0) return AppColor.lowConsumption;
    if (value < 7.0) return AppColor.mediumConsumption;
    return AppColor.highConsumption;
  }
}

Widget _buildTopStats() {
    return Column(
      children: [
        Row(
          children: const [
            Text(
              'Current Power Rate:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Spacer(),
            Text('₱10.25 / kWh', style: TextStyle(color: Colors.green)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: const [
            Text('Registered Address:'),
            Spacer(),
            Text('P-7, San Vicente Alto', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: const [
            Text('City:'),
            Spacer(),
            Text('Oroquieta City', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: const [
            Text('Municipality:'),
            Spacer(),
            Text('Misamis Occidentals', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }