import 'package:exercise_app/constants/constant.dart';
import 'package:flutter/material.dart';
import 'package:exercise_app/pages/monitoring/widgets/monitoring_header_card.dart';
import 'package:exercise_app/pages/monitoring/widgets/monitoring_chart_card.dart';
import 'package:exercise_app/pages/monitoring/widgets/monitoring_status_card.dart';
import 'package:exercise_app/services/power_rate_service.dart';
import 'package:exercise_app/pages/monitoring/widgets/predictive_consumption_card.dart';
import 'package:exercise_app/pages/monitoring/widgets/prediction_charts_card.dart';
import 'package:exercise_app/services/prediction_service.dart';
import 'package:exercise_app/services/monitoring_dataset_service.dart';
import 'package:exercise_app/models/prediction_result_model.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  String selectedPeriod = 'Week';
  final List<String> periods = ['Day', 'Week', 'Month'];
  bool _isLoading = false;

  // Services
  final PowerRateService _powerRateService = PowerRateService();
  final PredictionService _predictionService = PredictionService();
  final MonitoringDatasetService _monitoringDatasetService =
      MonitoringDatasetService();

  // State
  PredictionResultModel? _currentPrediction;

  @override
  void initState() {
    super.initState();
    _powerRateService.initialize();
    _monitoringDatasetService.initialize();
    _loadLatestPrediction();
  }

  @override
  void dispose() {
    _monitoringDatasetService.dispose();
    super.dispose();
  }

  Future<void> _loadLatestPrediction() async {
    final prediction = await _predictionService.getLatestPrediction();
    if (mounted) {
      setState(() {
        _currentPrediction = prediction;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonitoringHeaderCard(selectedPeriod: selectedPeriod),
                  SizedBox(height: Insets.lg),
                  _buildPeriodSelector(context),
                  SizedBox(height: Insets.md),
                  MonitoringChartCard(period: selectedPeriod),
                  SizedBox(height: Insets.md),
                  MonitoringStatusOverview(),
                  SizedBox(height: Insets.lg),
                  // AI Predictive Consumption Feature
                  PredictiveConsumptionCard(),
                  SizedBox(height: Insets.lg),
                  // Prediction Charts
                  PredictionChartsCard(prediction: _currentPrediction),
                  SizedBox(height: Insets.lg),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withAlpha(64),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    return Row(
      children: [
        Text('Period:', style: ResponsiveText.body(context)),
        SizedBox(width: Insets.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  periods.map((period) {
                    final isSelected = period == selectedPeriod;
                    return GestureDetector(
                      onTap: () => setState(() => selectedPeriod = period),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: Insets.sm),
                        padding: EdgeInsets.symmetric(
                          horizontal: Insets.md,
                          vertical: Insets.sm,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColor.primary
                                  : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              isSelected
                                  ? null
                                  : Border.all(
                                    color: AppColor.disabled,
                                    width: 1,
                                  ),
                        ),
                        child: Text(
                          period,
                          style: ResponsiveText.label(context).copyWith(
                            color:
                                isSelected
                                    ? Colors.white
                                    : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
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
}
