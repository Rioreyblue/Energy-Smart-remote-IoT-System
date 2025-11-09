import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/controllers/budget_controller.dart';
import 'package:exercise_app/services/power_rate_service.dart';

/// Widget for displaying and managing meter reading input
class MeterReadingSection extends StatefulWidget {
  final TextEditingController rateController;
  final TextEditingController previousReadingController;
  final TextEditingController presentReadingController;
  final DateTime selectedStartDate;
  final DateTime selectedEndDate;
  final BudgetController budgetController;
  final VoidCallback onCalculate;
  final VoidCallback onReset;
  final Function(bool isStartDate) onDateSelect;

  const MeterReadingSection({
    super.key,
    required this.rateController,
    required this.previousReadingController,
    required this.presentReadingController,
    required this.selectedStartDate,
    required this.selectedEndDate,
    required this.budgetController,
    required this.onCalculate,
    required this.onReset,
    required this.onDateSelect,
  });

  @override
  State<MeterReadingSection> createState() => _MeterReadingSectionState();
}

class _MeterReadingSectionState extends State<MeterReadingSection> {
  bool _isLoadingPowerRate = false;

  @override
  void initState() {
    super.initState();
    _loadPowerRate();
  }

  Future<void> _loadPowerRate() async {
    // If rate controller is empty or has default value, load from Firestore
    if (widget.rateController.text.isEmpty ||
        widget.rateController.text == '0.00' ||
        widget.rateController.text == '0') {
      setState(() => _isLoadingPowerRate = true);

      // Load rate without adding listeners to the singleton
      final powerRateService = PowerRateService();
      await powerRateService.initialize();

      if (mounted) {
        setState(() {
          _isLoadingPowerRate = false;
          // Only set if still empty
          if (widget.rateController.text.isEmpty ||
              widget.rateController.text == '0.00' ||
              widget.rateController.text == '0') {
            widget.rateController.text = powerRateService.currentRate
                .toStringAsFixed(2);
          }
        });
      }
    }
  }

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
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
          right: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
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
                Iconsax.document_text,
                color: AppColor.accentGreen,
                size: 24,
              ),
              SizedBox(width: Insets.sm),
              Text('Meter Reading Input', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Enter your meter readings to calculate energy consumption and estimated bill.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          // Live device data display
          ListenableBuilder(
            listenable: widget.budgetController,
            builder: (context, child) {
              if (widget.budgetController.totalKwhUsed > 0) {
                final primaryColor = Theme.of(context).colorScheme.primary;
                return Container(
                  padding: EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.flash_1, color: primaryColor, size: 20),
                      SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Device Total',
                              style: ResponsiveText.label(context),
                            ),
                            Text(
                              '${widget.budgetController.totalKwhUsed.toStringAsFixed(3)} kWh • ₱${NumberFormat.currency(locale: 'en_PH', symbol: '').format(widget.budgetController.consumedCost)}',
                              style: ResponsiveText.body(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
          if (widget.budgetController.totalKwhUsed > 0)
            SizedBox(height: Insets.md),

          // Rate per kWh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rate per kWh (₱)', style: ResponsiveText.label(context)),
              if (_isLoadingPowerRate)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                GestureDetector(
                  onTap: () async {
                    setState(() => _isLoadingPowerRate = true);
                    final powerRateService = PowerRateService();
                    await powerRateService.refresh();
                    if (mounted) {
                      setState(() {
                        _isLoadingPowerRate = false;
                        widget.rateController.text = powerRateService
                            .currentRate
                            .toStringAsFixed(2);
                      });
                    }
                  },
                  child: Icon(
                    Iconsax.refresh,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          SizedBox(height: Insets.sm),
          TextField(
            controller: widget.rateController,
            readOnly: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Rate: ₱${widget.rateController.text}/kWh',
              prefixIcon: Icon(Iconsax.money, color: AppColor.accentGreen),
              suffixIcon: Icon(
                Iconsax.info_circle,
                size: 16,
                color: AppColor.disabled,
              ),
              helperText: 'Fetched from admin settings (read-only)',
              helperStyle: ResponsiveText.caption(context),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.accentGreen, width: 2),
              ),
            ),
          ),
          SizedBox(height: Insets.md),

          // Date Range Selection
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Date', style: ResponsiveText.label(context)),
                    SizedBox(height: Insets.sm),
                    GestureDetector(
                      onTap: () => widget.onDateSelect(true),
                      child: Container(
                        padding: EdgeInsets.all(Insets.md),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColor.disabled),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.calendar,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: Insets.sm),
                            Text(
                              '${widget.selectedStartDate.day}/${widget.selectedStartDate.month}/${widget.selectedStartDate.year}',
                              style: ResponsiveText.body(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End Date', style: ResponsiveText.label(context)),
                    SizedBox(height: Insets.sm),
                    GestureDetector(
                      onTap: () => widget.onDateSelect(false),
                      child: Container(
                        padding: EdgeInsets.all(Insets.md),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColor.disabled),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.calendar,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: Insets.sm),
                            Text(
                              '${widget.selectedEndDate.day}/${widget.selectedEndDate.month}/${widget.selectedEndDate.year}',
                              style: ResponsiveText.body(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),

          // Previous Reading
          Text(
            'Previous Meter Reading (kWh)',
            style: ResponsiveText.label(context),
          ),
          SizedBox(height: Insets.sm),
          TextField(
            controller: widget.previousReadingController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'Enter previous reading',
              prefixIcon: Icon(
                Iconsax.document,
                color: Theme.of(context).colorScheme.primary,
              ),
              counterText: '', // Hide counter
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          SizedBox(height: Insets.md),

          // Present Reading
          Text(
            'Present Meter Reading (kWh)',
            style: ResponsiveText.label(context),
          ),
          SizedBox(height: Insets.sm),
          TextField(
            controller: widget.presentReadingController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'Enter present reading',
              prefixIcon: Icon(
                Iconsax.document,
                color: Theme.of(context).colorScheme.primary,
              ),
              counterText: '', // Hide counter
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          SizedBox(height: Insets.lg),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onCalculate,
                  icon: Icon(Iconsax.calculator, color: Colors.white),
                  label: Text(
                    'Calculate',
                    style: ResponsiveText.body(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.accentGreen,
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
                  onPressed: widget.onReset,
                  icon: Icon(
                    Iconsax.refresh,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Reset',
                    style: ResponsiveText.body(context).copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    padding: EdgeInsets.symmetric(vertical: Insets.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
