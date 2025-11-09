import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/controllers/budget_controller.dart';
import 'package:exercise_app/pages/goals/set_energy_target_page.dart';

/// Reusable widget for displaying budget target section
class BudgetTargetSection extends StatelessWidget {
  final BudgetController controller;
  final VoidCallback? onEditPressed;

  const BudgetTargetSection({
    super.key,
    required this.controller,
    this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final percentUsed = controller.consumptionPercentage / 100;
    final statusColor = Color(
      controller.getStatusColor(controller.consumptionPercentage.toInt()),
    );
    final statusText =
        percentUsed < 0.7
            ? 'Normal'
            : percentUsed < 0.9
            ? 'Warning'
            : 'Critical';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColor.accentGreen, width: 4),
          right: BorderSide(color: AppColor.accentGreen, width: 4),
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
              Icon(Iconsax.flag, color: AppColor.accentGreen, size: 24),
              SizedBox(width: Insets.sm),
              Text('Budget Target', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),

          if (controller.totalBudget == 0)
            // Empty state
            _buildEmptyState(context)
          else
            // Budget display
            _buildBudgetDisplay(context, percentUsed, statusColor, statusText),

          // Set Budget button
          _buildEditButton(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Lottie.asset(
            'assets/animations/energy_wave.json',
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: Insets.md),
        Text(
          'Set your budget target to track energy spending in real-time',
          style: ResponsiveText.body(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBudgetDisplay(
    BuildContext context,
    double percentUsed,
    Color statusColor,
    String statusText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentUsed.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: AppColor.disabled,
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          ),
        ),
        SizedBox(height: Insets.md),

        // Consumption info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Consumed', style: ResponsiveText.label(context)),
                  Text(
                    '₱${NumberFormat.currency(locale: 'en_PH', symbol: '').format(controller.consumedCost)} / ₱${NumberFormat.currency(locale: 'en_PH', symbol: '').format(controller.totalBudget)}',
                    style: ResponsiveText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(31),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: ResponsiveText.small(
                  context,
                ).copyWith(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        SizedBox(height: Insets.sm),

        // Remaining budget
        Container(
          padding: EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColor.accentGreen.withAlpha(26),
                AppColor.lowConsumption.withAlpha(26),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColor.accentGreen.withAlpha(77)),
          ),
          child: Row(
            children: [
              Icon(Iconsax.wallet_money, color: AppColor.accentGreen, size: 24),
              SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remaining Budget',
                      style: ResponsiveText.label(context),
                    ),
                    Text(
                      '₱${NumberFormat.currency(locale: 'en_PH', symbol: '').format(controller.remainingBudget)}',
                      style: ResponsiveText.headline(
                        context,
                      ).copyWith(color: AppColor.accentGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Insets.md),
      ],
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColor.accentGreen, AppColor.lowConsumption],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed:
              onEditPressed ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            SetEnergyTargetPage(controller: controller),
                  ),
                );
              },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: Insets.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.edit, color: Colors.white, size: 20),
              SizedBox(width: Insets.sm),
              Text(
                controller.totalBudget == 0 ? 'Set Budget' : 'Edit Budget',
                style: ResponsiveText.body(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
