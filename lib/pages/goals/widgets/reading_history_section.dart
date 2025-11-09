import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/models/goals_model.dart' as models;

/// Widget for displaying meter reading history
class ReadingHistorySection extends StatelessWidget {
  final List<models.MeterReadingModel> readingHistory;

  const ReadingHistorySection({super.key, required this.readingHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColor.accentRed, width: 4),
          right: BorderSide(color: AppColor.accentRed, width: 4),
        ),
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
          Row(
            children: [
              Icon(
                Iconsax.clock,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: Insets.sm),
              Text('Reading History', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Your recent meter readings and consumption history.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          // History List
          ...(readingHistory
              .take(5)
              .map((reading) => _buildHistoryItem(context, reading))
              .toList()),

          if (readingHistory.length > 5) ...[
            SizedBox(height: Insets.md),
            Center(
              child: Text(
                '${readingHistory.length - 5} more readings...',
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: AppColor.disabled),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    models.MeterReadingModel reading,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: Insets.sm),
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColor.disabled.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${reading.startDate.day}/${reading.startDate.month}/${reading.startDate.year} - ${reading.endDate.day}/${reading.endDate.month}/${reading.endDate.year}',
                style: ResponsiveText.label(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '₱${reading.estimatedBill.toStringAsFixed(2)}',
                style: ResponsiveText.body(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.xm),
          Row(
            children: [
              Icon(Iconsax.flash_1, color: AppColor.accentGreen, size: 16),
              SizedBox(width: Insets.xm),
              Text(
                '${reading.consumption.toStringAsFixed(2)} kWh',
                style: ResponsiveText.body(context),
              ),
              SizedBox(width: Insets.md),
              Icon(
                Iconsax.money,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              SizedBox(width: Insets.xm),
              Text(
                '₱${reading.ratePerKwh.toStringAsFixed(4)}/kWh',
                style: ResponsiveText.body(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
