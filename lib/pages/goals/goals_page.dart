import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/goals_service.dart';
import 'package:exercise_app/models/goals_model.dart' as models;

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  // Services
  final GoalsService _goalsService = GoalsService();

  // User Type Selection
  String? _selectedUserType;
  bool _showUserTypeSelection = true;

  // Energy Threshold State
  final TextEditingController _thresholdController = TextEditingController();
  double _energyThreshold = 0.0;
  bool _thresholdAlertEnabled = true;

  // Meter Reading State
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _previousReadingController =
      TextEditingController();
  final TextEditingController _presentReadingController =
      TextEditingController();
  DateTime _selectedStartDate = DateTime.now().subtract(
    const Duration(days: 30),
  );
  DateTime _selectedEndDate = DateTime.now();

  // Calculation Results
  double _consumption = 0.0;
  double _estimatedBill = 0.0;
  bool _showResults = false;

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;

  // History data
  List<models.MeterReadingModel> _readingHistory = [];

  @override
  void initState() {
    super.initState();
    _loadGoalsData();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _rateController.dispose();
    _previousReadingController.dispose();
    _presentReadingController.dispose();
    super.dispose();
  }

  // Load existing goals data
  Future<void> _loadGoalsData() async {
    setState(() => _isLoading = true);

    try {
      // Check if user type is already selected
      final userTypeResult = await _goalsService.getUserType();
      if (userTypeResult.isSuccess && userTypeResult.data != null) {
        setState(() {
          _selectedUserType = userTypeResult.data;
          _showUserTypeSelection = false;
        });
      }

      // Load energy threshold
      final goalsResult = await _goalsService.getEnergyThreshold();
      if (goalsResult.isSuccess && goalsResult.data != null) {
        final goals = goalsResult.data!;
        setState(() {
          _energyThreshold = goals.energyThreshold;
          _thresholdAlertEnabled = goals.thresholdAlertEnabled;
          _thresholdController.text = goals.energyThreshold.toString();
        });
      }

      // Load meter reading history
      final historyResult = await _goalsService.getMeterReadingsHistory();
      if (historyResult.isSuccess) {
        setState(() {
          _readingHistory = historyResult.data!;
        });
      }
    } catch (e) {
      debugPrint('Error loading goals data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateConsumption() {
    final previous = double.tryParse(_previousReadingController.text) ?? 0.0;
    final present = double.tryParse(_presentReadingController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    if (previous >= 0 && present >= 0 && rate > 0 && present >= previous) {
      setState(() {
        _consumption = present - previous;
        _estimatedBill = _consumption * rate;
        _showResults = true;
      });

      // Check for threshold alert
      _checkThresholdAlert();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter valid readings and rate'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    }
  }

  // Check if consumption exceeds 80% of threshold
  Future<void> _checkThresholdAlert() async {
    if (_energyThreshold > 0) {
      final threshold80Percent = _energyThreshold * 0.8;
      if (_consumption >= threshold80Percent) {
        await _goalsService.sendThresholdAlert(context, _consumption);
      }
    }
  }

  // Save energy threshold
  Future<void> _saveEnergyThreshold() async {
    if (_energyThreshold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid threshold amount'),
          backgroundColor: AppColor.accentRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final result = await _goalsService.saveEnergyThreshold(
        threshold: _energyThreshold,
        alertEnabled: _thresholdAlertEnabled,
      );

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Energy threshold saved successfully!'),
            backgroundColor: AppColor.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save threshold: ${result.error}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving threshold: $e'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Save meter reading
  Future<void> _saveMeterReading() async {
    setState(() => _isSaving = true);

    try {
      final result = await _goalsService.saveMeterReading(
        ratePerKwh: double.tryParse(_rateController.text) ?? 0.0,
        previousReading:
            double.tryParse(_previousReadingController.text) ?? 0.0,
        presentReading: double.tryParse(_presentReadingController.text) ?? 0.0,
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
      );

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reading saved successfully!'),
            backgroundColor: AppColor.accentGreen,
          ),
        );

        // Refresh history
        await _loadGoalsData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save reading: ${result.error}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving reading: $e'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Handle user type selection
  void _onUserTypeSelected() {
    if (_selectedUserType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a user type'),
          backgroundColor: AppColor.accentRed,
        ),
      );
      return;
    }

    _showUserTypeConfirmationDialog(context);
  }

  // Show confirmation dialog
  Future<void> _showUserTypeConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.all(Insets.lg),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: AppColor.accentRed.withAlpha(26),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Iconsax.warning_2,
                  color: AppColor.accentRed,
                  size: 32,
                ),
              ),
              SizedBox(height: Insets.lg),

              // Title
              Text(
                'Confirm User Type',
                style: ResponsiveText.stat(
                  context,
                ).copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Insets.md),

              // Message
              Text(
                'You have selected "${_selectedUserType == 'household' ? 'Household' : 'Small Business'}".\n\nThis choice cannot be changed after confirmation. Are you sure you want to proceed?',
                style: ResponsiveText.body(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Insets.lg),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.surface,
                        foregroundColor: AppColor.primary,
                        padding: EdgeInsets.symmetric(vertical: Insets.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: ResponsiveText.body(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(width: Insets.md),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColor.accentGreen,
                            AppColor.lowConsumption,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: _confirmUserTypeSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(vertical: Insets.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Confirm',
                          style: ResponsiveText.body(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Confirm user type selection
  Future<void> _confirmUserTypeSelection() async {
    Navigator.of(context).pop();

    setState(() => _isSaving = true);

    try {
      final result = await _goalsService.saveUserType(_selectedUserType!);

      if (result.isSuccess) {
        setState(() {
          _showUserTypeSelection = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User type saved successfully!'),
            backgroundColor: AppColor.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save user type: ${result.error}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving user type: $e'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _resetInputs() {
    setState(() {
      _rateController.clear();
      _previousReadingController.clear();
      _presentReadingController.clear();
      _showResults = false;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColor.primary),
                    SizedBox(height: Insets.md),
                    Text(
                      'Loading goals data...',
                      style: ResponsiveText.body(context),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header(
                    //   username: 'Rey Francisco',
                    //   responsiveFontSize: _responsiveFontSize,
                    // ),
                    // SizedBox(height: Insets.lg),

                    // User Type Selection (if not yet selected)
                    if (_showUserTypeSelection) ...[
                      _buildUserTypeSelectionSection(context),
                      SizedBox(height: Insets.lg),
                    ],

                    // Energy Threshold Section
                    _buildEnergyThresholdSection(context),
                    SizedBox(height: Insets.lg),

                    // Meter Reading Section
                    _buildMeterReadingSection(context),
                    SizedBox(height: Insets.lg),

                    // Results Section (if calculations are done)
                    if (_showResults) ...[
                      _buildResultsSection(context),
                      SizedBox(height: Insets.lg),
                    ],

                    // Reading History Section
                    if (_readingHistory.isNotEmpty) ...[
                      _buildHistorySection(context),
                      SizedBox(height: Insets.lg),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildUserTypeSelectionSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
              Icon(Iconsax.user, color: AppColor.accentGreen, size: 24),
              SizedBox(width: Insets.sm),
              Text('Type of User', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Please select your user type to personalize your energy management experience.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          // User Type Options
          Row(
            children: [
              Expanded(
                child: _buildUserTypeOption(
                  context,
                  'Household',
                  Iconsax.home,
                  'household',
                ),
              ),
              SizedBox(width: Insets.md),
              Expanded(
                child: _buildUserTypeOption(
                  context,
                  'Small Business',
                  Iconsax.building,
                  'small_business',
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.lg),

          // Confirm Button
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
                onPressed:
                    _selectedUserType != null ? _onUserTypeSelected : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: Insets.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm Selection',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeOption(
    BuildContext context,
    String title,
    IconData icon,
    String value,
  ) {
    final isSelected = _selectedUserType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserType = value;
        });
      },
      child: Container(
        padding: EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColor.accentGreen.withAlpha(26)
                  : AppColor.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColor.accentGreen : AppColor.disabled,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColor.accentGreen : AppColor.disabled,
              size: 32,
            ),
            SizedBox(height: Insets.sm),
            Text(
              title,
              style: ResponsiveText.body(context).copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColor.accentGreen : AppColor.disabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyThresholdSection(BuildContext context) {
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
              Text(
                'Energy Threshold Setting',
                style: ResponsiveText.stat(context),
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Set your energy consumption target to receive alerts when you reach 80% of your threshold.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          // Threshold Input
          Text('Target Price (₱)', style: ResponsiveText.label(context)),
          SizedBox(height: Insets.sm),
          TextField(
            controller: _thresholdController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter target price in pesos',
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
            onChanged: (value) {
              setState(() {
                _energyThreshold = double.tryParse(value) ?? 0.0;
              });
            },
          ),
          SizedBox(height: Insets.md),

          // Alert Toggle
          Row(
            children: [
              Switch(
                value: _thresholdAlertEnabled,
                onChanged: (value) {
                  setState(() {
                    _thresholdAlertEnabled = value;
                  });
                },
                activeColor: AppColor.accentGreen,
              ),
              SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'Enable 80% threshold alerts',
                  style: ResponsiveText.body(context),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),

          // // Save Button
          // SizedBox(
          //   width: double.infinity,
          //   child: ElevatedButton(
          //     onPressed: _isSaving ? null : _saveEnergyThreshold,
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: AppColor.accentGreen,
          //       foregroundColor: Colors.white,
          //       padding: EdgeInsets.symmetric(vertical: Insets.md),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(12),
          //       ),
          //     ),
          //     child:
          //         _isSaving
          //             ? Row(
          //               mainAxisAlignment: MainAxisAlignment.center,
          //               children: [
          //                 SizedBox(
          //                   width: 16,
          //                   height: 16,
          //                   child: CircularProgressIndicator(
          //                     strokeWidth: 2,
          //                     valueColor: AlwaysStoppedAnimation<Color>(
          //                       Colors.white,
          //                     ),
          //                   ),
          //                 ),
          //                 SizedBox(width: Insets.sm),
          //                 Text(
          //                   'Saving...',
          //                   style: ResponsiveText.body(context).copyWith(
          //                     color: Colors.white,
          //                     fontWeight: FontWeight.w600,
          //                   ),
          //                 ),
          //               ],
          //             )
          //             : Text(
          //               'Save Threshold',
          //               style: ResponsiveText.body(context).copyWith(
          //                 color: Colors.white,
          //                 fontWeight: FontWeight.w600,
          //               ),
          //             ),
          //   ),
          // ),
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
                onPressed: _isSaving ? null : _saveEnergyThreshold,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, // Show gradient
                  shadowColor: Colors.transparent, // Remove shadow
                  padding: EdgeInsets.symmetric(vertical: Insets.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isSaving
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
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
                          'Save Threshold',
                          style: ResponsiveText.body(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterReadingSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColor.primary, width: 4),
          right: BorderSide(color: AppColor.primary, width: 4),
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

          // Rate per kWh
          Text('Rate per kWh (₱)', style: ResponsiveText.label(context)),
          SizedBox(height: Insets.sm),
          TextField(
            controller: _rateController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter rate per kWh',
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
                      onTap: () => _selectDate(context, true),
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
                              color: AppColor.primary,
                              size: 20,
                            ),
                            SizedBox(width: Insets.sm),
                            Text(
                              '${_selectedStartDate.day}/${_selectedStartDate.month}/${_selectedStartDate.year}',
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
                      onTap: () => _selectDate(context, false),
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
                              color: AppColor.primary,
                              size: 20,
                            ),
                            SizedBox(width: Insets.sm),
                            Text(
                              '${_selectedEndDate.day}/${_selectedEndDate.month}/${_selectedEndDate.year}',
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
            controller: _previousReadingController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter previous reading',
              prefixIcon: Icon(Iconsax.document, color: AppColor.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.primary, width: 2),
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
            controller: _presentReadingController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter present reading',
              prefixIcon: Icon(Iconsax.document, color: AppColor.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.primary, width: 2),
              ),
            ),
          ),
          SizedBox(height: Insets.lg),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _calculateConsumption,
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
                  onPressed: _resetInputs,
                  icon: Icon(Iconsax.refresh, color: AppColor.primary),
                  label: Text(
                    'Reset',
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.surface,
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

  Widget _buildResultsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColor.lowConsumption, width: 4),
          right: BorderSide(color: AppColor.lowConsumption, width: 4),
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
              Icon(Iconsax.chart_2, color: AppColor.accentGreen, size: 24),
              SizedBox(width: Insets.sm),
              Text('Calculation Results', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),

          // Consumption Result
          Container(
            padding: EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: AppColor.accentGreen.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Iconsax.flash_1, color: AppColor.accentGreen, size: 20),
                SizedBox(width: Insets.sm),
                Text(
                  'Energy Consumption: ',
                  style: ResponsiveText.body(context),
                ),
                Text(
                  '${_consumption.toStringAsFixed(2)} kWh',
                  style: ResponsiveText.body(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColor.accentGreen,
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
              color: AppColor.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Iconsax.money, color: AppColor.primary, size: 20),
                SizedBox(width: Insets.sm),
                Text('Estimated Bill: ', style: ResponsiveText.body(context)),
                Text(
                  '₱${_estimatedBill.toStringAsFixed(2)}',
                  style: ResponsiveText.body(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColor.primary,
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
                  onPressed: _isSaving ? null : _saveMeterReading,
                  icon: Icon(Iconsax.save_2, color: Colors.white),
                  label: Text(
                    'Save Reading',
                    style: ResponsiveText.body(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primary,
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
                  onPressed: () {
                    setState(() {
                      _showResults = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Results dismissed'),
                        backgroundColor: AppColor.accentGreen,
                      ),
                    );
                  },
                  icon: Icon(Iconsax.close_circle, color: AppColor.accentRed),
                  label: Text(
                    'Dismiss',
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.accentRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.surface,
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

  Widget _buildHistorySection(BuildContext context) {
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
              Icon(Iconsax.clock, color: AppColor.primary, size: 24),
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
          ...(_readingHistory
              .take(5)
              .map((reading) => _buildHistoryItem(context, reading))
              .toList()),

          if (_readingHistory.length > 5) ...[
            SizedBox(height: Insets.md),
            Center(
              child: Text(
                '${_readingHistory.length - 5} more readings...',
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
        color: AppColor.surface,
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
                  color: AppColor.primary,
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
              Icon(Iconsax.money, color: AppColor.primary, size: 16),
              SizedBox(width: Insets.xm),
              Text(
                '₱${reading.ratePerKwh.toStringAsFixed(2)}/kWh',
                style: ResponsiveText.body(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
