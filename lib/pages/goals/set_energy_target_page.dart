import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/controllers/budget_controller.dart';
import 'package:exercise_app/utils/snackbar_utils.dart';
import 'package:exercise_app/services/power_rate_service.dart';

/// Full page for setting/editing energy target (budget) configuration
class SetEnergyTargetPage extends StatefulWidget {
  final BudgetController controller;

  const SetEnergyTargetPage({super.key, required this.controller});

  @override
  State<SetEnergyTargetPage> createState() => _SetEnergyTargetPageState();
}

class _SetEnergyTargetPageState extends State<SetEnergyTargetPage> {
  late TextEditingController _totalBudgetController;
  late TextEditingController _rateController;

  double _thresholdSlider = 80;
  bool _alertEnabled = true;
  bool _isSaving = false;
  bool _isLoadingPowerRate = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current values from budget controller
    _totalBudgetController = TextEditingController(
      text:
          widget.controller.totalBudget > 0
              ? widget.controller.totalBudget.toStringAsFixed(2)
              : '',
    );
    _rateController = TextEditingController(
      text:
          widget.controller.ratePerKwh > 0
              ? widget.controller.ratePerKwh.toStringAsFixed(2)
              : '',
    );

    // Initialize threshold and alert settings
    _thresholdSlider = widget.controller.thresholdPercentage.toDouble();
    _alertEnabled = widget.controller.alertEnabled;

    // Load power rate if needed
    _loadPowerRate();
  }

  @override
  void dispose() {
    // Properly dispose all controllers
    _totalBudgetController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _loadPowerRate() async {
    // If rate controller is empty or has default value, load from Firestore
    if (_rateController.text.isEmpty ||
        _rateController.text == '0.00' ||
        _rateController.text == '0') {
      setState(() => _isLoadingPowerRate = true);

      // Load rate without adding listeners to the singleton
      final powerRateService = PowerRateService();
      await powerRateService.initialize();

      if (mounted) {
        setState(() {
          _isLoadingPowerRate = false;
          // Only set if still empty
          if (_rateController.text.isEmpty ||
              _rateController.text == '0.00' ||
              _rateController.text == '0') {
            _rateController.text = powerRateService.currentRate.toStringAsFixed(
              2,
            );
          }
        });
      }
    }
  }

  Future<void> _refreshPowerRate() async {
    setState(() => _isLoadingPowerRate = true);
    final powerRateService = PowerRateService();
    await powerRateService.refresh();
    if (mounted) {
      setState(() {
        _isLoadingPowerRate = false;
        _rateController.text = powerRateService.currentRate.toStringAsFixed(2);
      });
    }
  }

  Future<void> _handleSave() async {
    final totalBudget = double.tryParse(_totalBudgetController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;

    if (totalBudget <= 0 || rate <= 0) {
      if (mounted) {
        showErrorSnackBar(context, 'Please enter valid budget and rate values');
      }
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.controller.saveSettings(
      newTotalBudget: totalBudget,
      newRatePerKwh: rate,
      newThresholdPercentage: _thresholdSlider.toInt(),
      newAlertEnabled: _alertEnabled,
    );

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        showSuccessSnackBar(context, 'Budget saved successfully!');
        // Navigate back after a short delay to show the success message
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        showErrorSnackBar(context, 'Failed to save budget');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Iconsax.setting_2, color: AppColor.accentGreen, size: 24),
            const SizedBox(width: Insets.sm),
            Text(
              'Energy Target Settings',
              style: ResponsiveText.title(context),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Budget Section
            Text('Total Budget (₱)', style: ResponsiveText.label(context)),
            SizedBox(height: Insets.sm),
            TextField(
              controller: _totalBudgetController,
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
            SizedBox(height: Insets.lg),

            // Rate per kWh Section
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
                    onTap: _refreshPowerRate,
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
              controller: _rateController,
              readOnly: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Rate: ₱${_rateController.text}/kWh',
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
            SizedBox(height: Insets.lg),

            // Threshold Slider Section
            Text(
              'Alert Threshold: ${_thresholdSlider.toInt()}%',
              style: ResponsiveText.label(context),
            ),
            SizedBox(height: Insets.sm),
            Slider(
              value: _thresholdSlider,
              min: 50,
              max: 95,
              divisions: 9,
              label: '${_thresholdSlider.toInt()}%',
              activeColor: AppColor.accentGreen,
              onChanged: (value) => setState(() => _thresholdSlider = value),
            ),
            SizedBox(height: Insets.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('50%', style: ResponsiveText.caption(context)),
                Text('95%', style: ResponsiveText.caption(context)),
              ],
            ),
            SizedBox(height: Insets.lg),

            // Alert Toggle Section
            Row(
              children: [
                Switch(
                  value: _alertEnabled,
                  onChanged: (value) => setState(() => _alertEnabled = value),
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
            SizedBox(height: Insets.xl),

            // Save Button
            SizedBox(
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
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: Insets.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isSaving
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.tick_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: Insets.sm),
                              Text(
                                'Save Settings',
                                style: ResponsiveText.body(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
