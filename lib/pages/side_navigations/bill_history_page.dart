import 'package:flutter/material.dart';
import '../../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import '../../widgets/card.dart';
import '../../services/trends_service.dart';
import '../../models/trends_model.dart';
import 'package:go_router/go_router.dart';

class BillHistoryPage extends StatefulWidget {
  const BillHistoryPage({super.key});

  @override
  State<BillHistoryPage> createState() => _BillHistoryPageState();
}

class _BillHistoryPageState extends State<BillHistoryPage> {
  final TrendsService _trendsService = TrendsService();
  String _selectedPeriod = 'monthly';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Trends'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_1),
          onPressed: () => context.go('/home'),
          color: Colors.white,
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'daily', child: Text('Daily')),
                  const PopupMenuItem(value: 'weekly', child: Text('Weekly')),
                  const PopupMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Energy Usage Trends',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Period: ${_selectedPeriod.toUpperCase()}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColor.disabled),
            ),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: StreamBuilder<List<TrendsModel>>(
                stream: _getTrendsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.warning_2,
                            color: AppColor.accentRed,
                            size: 48,
                          ),
                          const SizedBox(height: Insets.md),
                          Text(
                            'Error loading trends',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            snapshot.error.toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.chart_2,
                            color: AppColor.disabled,
                            size: 48,
                          ),
                          const SizedBox(height: Insets.md),
                          Text(
                            'No trends data available',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            'Your energy usage trends will appear here',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColor.disabled),
                          ),
                        ],
                      ),
                    );
                  }

                  final trends = snapshot.data!;
                  return ListView.separated(
                    itemCount: trends.length,
                    separatorBuilder:
                        (_, __) => const SizedBox(height: Insets.sm),
                    itemBuilder: (context, index) {
                      final trend = trends[index];
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getTrendIcon(_selectedPeriod),
                                  color: AppColor.accentGreen,
                                  size: 28,
                                ),
                                const SizedBox(width: Insets.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trend.dateString,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${trend.formattedTotalKwh} • ${trend.formattedUsageTime}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      trend.formattedTotalCost,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        color: AppColor.accentGreen,
                                      ),
                                    ),
                                    if (trend.averageDailyKwh != null)
                                      Text(
                                        'Avg: ${trend.formattedAverageDailyKwh}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color: AppColor.disabled,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: Insets.sm),
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColor.accentGreen.withAlpha(26),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _getUsagePercentage(trend),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColor.accentGreen,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<TrendsModel>> _getTrendsStream() {
    switch (_selectedPeriod) {
      case 'daily':
        return _trendsService.listenToDailyTrends().map(
          (data) =>
              data
                  .map((item) => TrendsModel.fromFirestore(item['id'], item))
                  .toList(),
        );
      case 'weekly':
        return _trendsService.listenToWeeklyTrends().map(
          (data) =>
              data
                  .map((item) => TrendsModel.fromFirestore(item['id'], item))
                  .toList(),
        );
      case 'monthly':
        return _trendsService.listenToMonthlyTrends().map(
          (data) =>
              data
                  .map((item) => TrendsModel.fromFirestore(item['id'], item))
                  .toList(),
        );
      default:
        return _trendsService.listenToMonthlyTrends().map(
          (data) =>
              data
                  .map((item) => TrendsModel.fromFirestore(item['id'], item))
                  .toList(),
        );
    }
  }

  IconData _getTrendIcon(String period) {
    switch (period) {
      case 'daily':
        return Iconsax.calendar_1;
      case 'weekly':
        return Iconsax.calendar_2;
      case 'monthly':
        return Iconsax.calendar;
      default:
        return Iconsax.chart_2;
    }
  }

  double _getUsagePercentage(TrendsModel trend) {
    // Calculate percentage based on total kWh (assuming max is 50 kWh for visualization)
    const maxKwh = 50.0;
    return (trend.totalKwh / maxKwh).clamp(0.0, 1.0);
  }
}
