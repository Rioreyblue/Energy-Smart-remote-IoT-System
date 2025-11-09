import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/controllers/budget_controller.dart';
import 'package:exercise_app/utils/snackbar_utils.dart';
import 'package:exercise_app/services/power_rate_service.dart';
import 'package:intl/intl.dart';

/// Dialog widget for setting/editing budget configuration
class SetBudgetDialog {
  /// Show the budget settings dialog
  static Future<void> show(
    BuildContext context,
    BudgetController controller,
  ) async {
    final totalBudgetController = TextEditingController(
      text:
          controller.totalBudget > 0
              ? controller.totalBudget.toStringAsFixed(2)
              : '',
    );
    final rateController = TextEditingController(
      text:
          controller.ratePerKwh > 0
              ? controller.ratePerKwh.toStringAsFixed(4)
              : '',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _DialogContent(
          parentContext: context,
          dialogContext: dialogContext,
          controller: controller,
          totalBudgetController: totalBudgetController,
          rateController: rateController,
        );
      },
    ).then((_) {
      // Dispose controllers after dialog closes
      totalBudgetController.dispose();
      rateController.dispose();
    });
  }
}

class _DialogContent extends StatefulWidget {
  final BuildContext parentContext;
  final BuildContext dialogContext;
  final BudgetController controller;
  final TextEditingController totalBudgetController;
  final TextEditingController rateController;

  const _DialogContent({
    required this.parentContext,
    required this.dialogContext,
    required this.controller,
    required this.totalBudgetController,
    required this.rateController,
  });

  @override
  State<_DialogContent> createState() => _DialogContentState();
}

class _DialogContentState extends State<_DialogContent> {
  double thresholdSlider = 80;
  bool alertEnabled = true;
  bool isSaving = false;
  bool _isLoadingPowerRate = false;

  @override
  void initState() {
    super.initState();
    thresholdSlider = widget.controller.thresholdPercentage.toDouble();
    alertEnabled = widget.controller.alertEnabled;
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
                .toStringAsFixed(4);
          }
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final totalBudget = double.tryParse(widget.totalBudgetController.text) ?? 0;
    final rate = double.tryParse(widget.rateController.text) ?? 0;

    if (totalBudget <= 0 || rate <= 0) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Please enter valid budget and rate values');
      }
      return;
    }

    setState(() => isSaving = true);

    final success = await widget.controller.saveSettings(
      newTotalBudget: totalBudget,
      newRatePerKwh: rate,
      newThresholdPercentage: thresholdSlider.toInt(),
      newAlertEnabled: alertEnabled,
    );

    // Close dialog first
    if (widget.dialogContext.mounted) {
      Navigator.of(widget.dialogContext).pop();
    }

    // Then show snackbar using the page context
    // Add small delay to ensure dialog is closed
    await Future.delayed(Duration(milliseconds: 100));

    // Use the parent context for ScaffoldMessenger
    if (widget.parentContext.mounted) {
      if (success) {
        showSuccessSnackBar(widget.parentContext, 'Budget saved successfully!');
      } else {
        showErrorSnackBar(widget.parentContext, 'Failed to save budget');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Iconsax.setting_2, color: AppColor.accentGreen),
          SizedBox(width: Insets.sm),
          Text('Budget Settings', style: ResponsiveText.title(context)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Budget
            Text('Total Budget (₱)', style: ResponsiveText.label(context)),
            SizedBox(height: Insets.sm),
            TextField(
              controller: widget.totalBudgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter total budget',
                prefixIcon: Icon(Iconsax.money, color: AppColor.accentGreen),
                border: OutlineInputBorder(
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
                              .toStringAsFixed(4);
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
                prefixIcon: Icon(
                  Iconsax.flash_1,
                  color: Theme.of(context).colorScheme.primary,
                ),
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

            // Threshold Slider
            Text(
              'Alert Threshold: ${thresholdSlider.toInt()}%',
              style: ResponsiveText.label(context),
            ),
            SizedBox(height: Insets.sm),
            Slider(
              value: thresholdSlider,
              min: 50,
              max: 95,
              divisions: 9,
              label: '${thresholdSlider.toInt()}%',
              activeColor: AppColor.accentGreen,
              onChanged: (value) => setState(() => thresholdSlider = value),
            ),
            SizedBox(height: Insets.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('50%', style: ResponsiveText.caption(context)),
                Text('95%', style: ResponsiveText.caption(context)),
              ],
            ),
            SizedBox(height: Insets.md),

            // Alert Toggle
            Row(
              children: [
                Switch(
                  value: alertEnabled,
                  onChanged: (value) => setState(() => alertEnabled = value),
                ),
                SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'Enable Budget Alerts',
                    style: ResponsiveText.body(context),
                  ),
                ),
              ],
            ),
            if (widget.controller.lastAlertDismissedAt != null) ...[
              SizedBox(height: Insets.md),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Insets.sm),
                decoration: BoxDecoration(
                  color: AppColor.accentGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Last alert dismissed: ${DateFormat.yMMMEd().add_jm().format(widget.controller.lastAlertDismissedAt!)}',
                  style: ResponsiveText.caption(context).copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              isSaving ? null : () => Navigator.of(widget.dialogContext).pop(),
          child: Text('Cancel', style: ResponsiveText.body(context)),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColor.accentGreen,
            foregroundColor: Colors.white,
          ),
          child:
              isSaving
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: Insets.sm),
                      Text(
                        'Saving...',
                        style: ResponsiveText.body(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                  : Text(
                    'Save',
                    style: ResponsiveText.body(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ],
    );
  }
}
