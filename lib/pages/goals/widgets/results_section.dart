import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';

/// Widget for displaying calculation results
class ResultsSection extends StatelessWidget {
  final double consumption;
  final double estimatedBill;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  const ResultsSection({
    super.key,
    required this.consumption,
    required this.estimatedBill,
    required this.isSaving,
    required this.onSave,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
            width: 4,
          ),
          right: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withAlpha((0.3 * 255).toInt())
                    : Colors.black.withAlpha((0.05 * 255).toInt()),
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
                Iconsax.chart_2,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: Insets.sm),
              Text(
                'Calculation Results',
                style: ResponsiveText.stat(
                  context,
                ).copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          SizedBox(height: Insets.md),

          // Consumption Result
          Container(
            padding: EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.flash_1,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                SizedBox(width: Insets.sm),
                Text(
                  'Energy Consumption: ',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
                Text(
                  '${consumption.toStringAsFixed(2)} kWh',
                  style: ResponsiveText.body(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Insets.sm),

          // Bill Estimate
          Container(
            padding: EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.money,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                SizedBox(width: Insets.sm),
                Text(
                  'Estimated Bill: ',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
                Text(
                  '₱${estimatedBill.toStringAsFixed(2)}',
                  style: ResponsiveText.body(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Insets.md),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: Icon(
                    Iconsax.save_2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  label: Text(
                    'Save Reading',
                    style: ResponsiveText.body(context).copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(vertical: Insets.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: Insets.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDismiss,
                  icon: Icon(Iconsax.close_circle, color: AppColor.accentRed),
                  label: Text(
                    'Dismiss',
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.accentRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    padding: EdgeInsets.symmetric(vertical: Insets.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColor.accentRed),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
