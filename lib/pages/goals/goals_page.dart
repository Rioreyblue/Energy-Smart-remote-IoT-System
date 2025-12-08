import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/goals_service.dart';
import 'package:exercise_app/controllers/budget_controller.dart';
import 'package:exercise_app/models/goals_model.dart' as models;
import 'package:exercise_app/pages/goals/widgets/budget_target_section.dart';
import 'package:exercise_app/pages/goals/widgets/meter_reading_section.dart';
import 'package:exercise_app/pages/goals/widgets/results_section.dart';
import 'package:exercise_app/pages/goals/widgets/reading_history_section.dart';
import 'package:exercise_app/utils/snackbar_utils.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  // Services
  final GoalsService _goalsService = GoalsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User Type Selection
  String? _selectedUserType;
  bool _showUserTypeSelection = true;

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

  /// Get current user ID
  String get _userId => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadGoalsData();
  }

  @override
  void dispose() {
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
    } else {
      showErrorSnackBar(context, 'Please enter valid readings and rate');
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
        if (mounted) {
          showSuccessSnackBar(context, 'Reading saved successfully!');
        }

        // Refresh history
        await _loadGoalsData();
      } else {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to save reading: ${result.error}');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error saving reading: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Handle user type selection
  void _onUserTypeSelected() {
    if (_selectedUserType == null) {
      showErrorSnackBar(context, 'Please select a user type');
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
                style: ResponsiveText.stat(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Insets.md),

              // Message
              Text(
                'You have selected "${_selectedUserType == 'household' ? 'Household' : 'Small Business'}".\n\nThis choice cannot be changed after confirmation. Are you sure you want to proceed?',
                style: ResponsiveText.body(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                ),
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
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onPrimary,
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
      debugPrint('🔍 [GoalsPage] Saving user type: $_selectedUserType');
      debugPrint('🔍 [GoalsPage] User ID: $_userId');

      final result = await _goalsService.saveUserType(_selectedUserType!);

      if (result.isSuccess) {
        debugPrint('✅ [GoalsPage] User type saved successfully');
        setState(() {
          _showUserTypeSelection = false;
        });

        if (mounted) {
          showSuccessSnackBar(context, 'User type saved successfully!');
        }
      } else {
        debugPrint('❌ [GoalsPage] Failed to save user type: ${result.error}');
        if (mounted) {
          showErrorSnackBar(
            context,
            'Failed to save user type: ${result.error}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [GoalsPage] Error saving user type: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Error saving user type: $e');
      }
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
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: Insets.md),
                    Text(
                      'Loading goals data...',
                      style: ResponsiveText.body(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showUserTypeSelection) ...[
                      _buildUserTypeSelectionSection(context),
                      SizedBox(height: Insets.lg),
                    ],

                    // Energy Threshold Section
                    Consumer<BudgetController>(
                      builder: (context, budgetController, child) {
                        return BudgetTargetSection(
                          controller: budgetController,
                        );
                      },
                    ),
                    SizedBox(height: Insets.lg),

                    // Meter Reading Section
                    MeterReadingSection(
                      rateController: _rateController,
                      previousReadingController: _previousReadingController,
                      presentReadingController: _presentReadingController,
                      selectedStartDate: _selectedStartDate,
                      selectedEndDate: _selectedEndDate,
                      budgetController: context.read<BudgetController>(),
                      onCalculate: _calculateConsumption,
                      onReset: _resetInputs,
                      onDateSelect:
                          (isStartDate) => _selectDate(context, isStartDate),
                    ),
                    SizedBox(height: Insets.lg),

                    // Results Section (if calculations are done)
                    if (_showResults) ...[
                      ResultsSection(
                        consumption: _consumption,
                        estimatedBill: _estimatedBill,
                        isSaving: _isSaving,
                        onSave: _saveMeterReading,
                        onDismiss: () {
                          setState(() {
                            _showResults = false;
                          });
                        },
                      ),
                      SizedBox(height: Insets.lg),
                    ],

                    // Reading History Section
                    if (_readingHistory.isNotEmpty) ...[
                      ReadingHistorySection(readingHistory: _readingHistory),
                      SizedBox(height: Insets.lg),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildUserTypeSelectionSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                isDark
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
                Iconsax.user,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: Insets.sm),
              Text(
                'Type of User',
                style: ResponsiveText.stat(
                  context,
                ).copyWith(color: colorScheme.onSurface),
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Please select your user type to personalize your energy management experience.',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: colorScheme.onSurface.withAlpha(179)),
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
                  style: ResponsiveText.body(context).copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildUserTypeOption(
    BuildContext context,
    String title,
    IconData icon,
    String value,
  ) {
    final isSelected = _selectedUserType == value;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

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
                  ? AppColor.accentGreen.withAlpha(isDark ? 40 : 26)
                  : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppColor.accentGreen
                    : colorScheme.outline.withAlpha(77),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? AppColor.accentGreen
                      : colorScheme.onSurface.withAlpha(128),
              size: 32,
            ),
            SizedBox(height: Insets.sm),
            Text(
              title,
              style: ResponsiveText.body(context).copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color:
                    isSelected
                        ? AppColor.accentGreen
                        : colorScheme.onSurface.withAlpha(179),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
