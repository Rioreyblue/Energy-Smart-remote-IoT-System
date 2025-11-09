import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/predictive_dataset_service.dart';
import 'package:exercise_app/services/prediction_service.dart';
import 'package:exercise_app/utils/snackbar_utils.dart';
import 'package:exercise_app/models/prediction_result_model.dart';
import 'package:exercise_app/utils/monitoring_prediction_utils.dart';

class PredictiveConsumptionCard extends StatefulWidget {
  const PredictiveConsumptionCard({super.key});

  @override
  State<PredictiveConsumptionCard> createState() =>
      _PredictiveConsumptionCardState();
}

class _PredictiveConsumptionCardState extends State<PredictiveConsumptionCard> {
  final PredictiveDatasetService _datasetService = PredictiveDatasetService();
  final PredictionService _predictionService = PredictionService();
  PredictionResultModel? _currentPrediction;
  bool _isGeneratingPrediction = false;

  @override
  void initState() {
    super.initState();
    _datasetService.initialize();
    _loadLatestPrediction();
    _datasetService.addListener(_onDatasetChanged);
  }

  @override
  void dispose() {
    _datasetService.removeListener(_onDatasetChanged);
    super.dispose();
  }

  void _onDatasetChanged() {
    if (_datasetService.hasDataset && mounted) {
      _generatePrediction();
    }
  }

  void _onRefreshPressed() {
    if (_datasetService.hasDataset) {
      _generatePrediction();
    }
  }

  Future<void> _loadLatestPrediction() async {
    final prediction = await _predictionService.getLatestPrediction();
    if (mounted) {
      setState(() {
        _currentPrediction = prediction;
      });
    }
  }

  Future<void> _generatePrediction() async {
    if (!_datasetService.hasDataset) return;

    setState(() {
      _isGeneratingPrediction = true;
    });

    try {
      final prediction = await _predictionService.generatePrediction(
        dataset: _datasetService.dataset,
        saveToFirestore: true,
      );

      if (mounted) {
        setState(() {
          _currentPrediction = prediction;
          _isGeneratingPrediction = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingPrediction = false;
        });
        showErrorSnackBar(context, 'Failed to generate prediction: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _datasetService,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColor.accentGreen, AppColor.lowConsumption],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.1 * 255).toInt()),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Iconsax.chart_21, color: Colors.white, size: 24),
                  SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'AI Predictive Consumption',
                      style: ResponsiveText.title(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Iconsax.refresh, color: Colors.white),
                    onPressed: _onRefreshPressed,
                    tooltip: 'Refresh Prediction',
                  ),
                ],
              ),
              SizedBox(height: Insets.lg),

              // Dataset Info with Source Indicator
              _buildDatasetInfo(context),
              SizedBox(height: Insets.sm),
              _buildDataSourceIndicator(context),
              SizedBox(height: Insets.md),

              // Prediction Summary
              if (_isGeneratingPrediction)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(Insets.lg),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: Insets.md),
                        Text(
                          'Generating prediction...',
                          style: ResponsiveText.body(
                            context,
                          ).copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_currentPrediction != null)
                _buildPredictionSummary(context, _currentPrediction!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDatasetInfo(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.2 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Iconsax.document, color: Colors.white, size: 20),
          SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dataset Loaded',
                  style: ResponsiveText.label(
                    context,
                  ).copyWith(color: Colors.white70),
                ),
                Text(
                  '${_datasetService.datasetSize} records',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (_datasetService.lastImportDate != null)
            Text(
              'Imported ${_formatDate(_datasetService.lastImportDate!)}',
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildDataSourceIndicator(BuildContext context) {
    final dataSourceType = _datasetService.dataSource;
    final dataSourceInfo = _datasetService.getDataSourceInfo();
    final isOnline = dataSourceInfo['isOnline'] as bool? ?? false;
    final lastSyncTime = dataSourceInfo['lastSyncTime'] as DateTime?;

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;
    String statusText;

    switch (dataSourceType) {
      case DataSourceType.cloud:
        badgeColor = AppColor.accentGreen;
        badgeIcon = Iconsax.cloud;
        badgeText = 'Cloud';
        statusText = 'Synced from Firestore';
        break;
      case DataSourceType.local:
        badgeColor = AppColor.mediumConsumption;
        badgeIcon = Iconsax.document_download;
        badgeText = 'Local';
        statusText = 'Offline backup';
        break;
      case DataSourceType.embedded:
        badgeColor = AppColor.disabled;
        badgeIcon = Iconsax.document;
        badgeText = 'Embedded';
        statusText = 'Default fallback';
        break;
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.15 * 255).toInt()),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: badgeColor.withAlpha((0.5 * 255).toInt()),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha((0.3 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(badgeIcon, color: Colors.white, size: 16),
              ),
              SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          badgeText,
                          style: ResponsiveText.label(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: Insets.xm),
                        // Online/Offline indicator
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                isOnline ? AppColor.accentGreen : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      statusText,
                      style: ResponsiveText.caption(
                        context,
                      ).copyWith(color: Colors.white70, fontSize: 10),
                    ),
                    // Last sync time
                    if (lastSyncTime != null) ...[
                      SizedBox(height: 2),
                      Text(
                        'Last sync: ${_formatDate(lastSyncTime)}',
                        style: ResponsiveText.caption(
                          context,
                        ).copyWith(color: Colors.white60, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
              if (dataSourceType != DataSourceType.cloud)
                _datasetService.isLoading || _isGeneratingPrediction
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : IconButton(
                      icon: Icon(
                        Iconsax.refresh,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _onSyncPressed,
                      tooltip:
                          dataSourceType == DataSourceType.embedded
                              ? 'Refresh Prediction'
                              : isOnline
                              ? 'Sync from Cloud'
                              : 'Offline - Cannot sync',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
            ],
          ),
        ),
        // Warning for embedded dataset
        if (dataSourceType == DataSourceType.embedded) ...[
          SizedBox(height: Insets.sm),
          Container(
            padding: EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              color: AppColor.accentRed.withAlpha((0.2 * 255).toInt()),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColor.accentRed.withAlpha((0.5 * 255).toInt()),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Iconsax.warning_2, color: AppColor.accentRed, size: 16),
                SizedBox(width: Insets.xm),
                Expanded(
                  child: Text(
                    'Using default dataset. Sync from cloud for accurate predictions.',
                    style: ResponsiveText.caption(
                      context,
                    ).copyWith(color: Colors.white, fontSize: 10),
                  ),
                ),
                TextButton(
                  onPressed: _onSyncPressed,
                  child: Text(
                    isOnline ? 'Sync Now' : 'Refresh Prediction',
                    style: ResponsiveText.caption(context).copyWith(
                      color: AppColor.accentRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onSyncPressed() async {
    if (_datasetService.isLoading) return;

    final dataSourceType = _datasetService.dataSource;

    // If using Embedded data source, just refresh prediction without connectivity check
    if (dataSourceType == DataSourceType.embedded) {
      setState(() {
        _isGeneratingPrediction = true;
      });

      try {
        // Just regenerate prediction from embedded dataset
        await _generatePrediction();
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to refresh prediction: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isGeneratingPrediction = false;
          });
        }
      }
      return;
    }

    // For Local or Cloud data sources, check connectivity before syncing
    setState(() {
      _isGeneratingPrediction = true;
    });

    try {
      // Refresh connectivity status before checking
      await _datasetService.refreshConnectivity();
      final isOnline = _datasetService.isOnline;

      if (!isOnline) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Cannot sync: Device is offline. Please check your internet connection.',
          );
        }
        return;
      }

      // Proceed with cloud sync
      final success = await _datasetService.syncFromCloud();
      if (success && mounted) {
        // Regenerate prediction with new dataset
        await _generatePrediction();
      } else if (mounted) {
        showErrorSnackBar(
          context,
          'Failed to sync from cloud. Please try again later.',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Sync failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPrediction = false;
        });
      }
    }
  }

  Widget _buildPredictionSummary(
    BuildContext context,
    PredictionResultModel prediction,
  ) {
    final costForecast = MonitoringPrediction.forecastCost(
      predictedKwh: prediction.predictedKwh,
    );

    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.2 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Predicted Consumption with Classification Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Predicted Next Month',
                style: ResponsiveText.label(
                  context,
                ).copyWith(color: Colors.white70),
              ),
              Row(
                children: [
                  Text(
                    prediction.formattedPredictedKwh,
                    style: ResponsiveText.stat(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: Insets.sm),
                  // Classification Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: prediction.consumptionLevelColor.withAlpha(
                        (0.9 * 255).toInt(),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.3 * 255).toInt()),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          prediction.consumptionLevelIcon,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          prediction.consumptionLevel.toUpperCase(),
                          style: ResponsiveText.caption(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Insets.xm),
          // Classification explanation
          Text(
            'Based on historical data, percentiles, and industry benchmarks',
            style: ResponsiveText.caption(
              context,
            ).copyWith(color: Colors.white70, fontStyle: FontStyle.italic),
          ),
          SizedBox(height: Insets.sm),

          // Cost Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Predicted Cost Range',
                style: ResponsiveText.label(
                  context,
                ).copyWith(color: Colors.white70),
              ),
              Text(
                '₱${costForecast['minCost']!.toStringAsFixed(2)} - ₱${costForecast['maxCost']!.toStringAsFixed(2)}',
                style: ResponsiveText.stat(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: Insets.sm),

          // Appliance Cost Analysis Section
          if (prediction.applianceCostBreakdown != null &&
              prediction.applianceCostBreakdown!.isNotEmpty) ...[
            SizedBox(height: Insets.md),
            Divider(
              color: Colors.white.withAlpha((0.3 * 255).toInt()),
              thickness: 1,
            ),
            SizedBox(height: Insets.sm),
            _buildApplianceCostAnalysis(context, prediction),
          ],

          // Confidence
          SizedBox(height: Insets.sm),
          Row(
            children: [
              Icon(Iconsax.shield_tick, color: Colors.white70, size: 16),
              SizedBox(width: Insets.xm),
              Text(
                'Confidence: ${prediction.formattedConfidence}',
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplianceCostAnalysis(
    BuildContext context,
    PredictionResultModel prediction,
  ) {
    final mostCostly = prediction.getMostCostlyApplianceDetails();
    final leastCostly = prediction.getLeastCostlyApplianceDetails();
    final appliancesByCost = prediction.getAppliancesByCost();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            Icon(Iconsax.info_circle, color: Colors.white70, size: 16),
            SizedBox(width: Insets.xm),
            Text(
              'Appliance Cost Analysis',
              style: ResponsiveText.label(
                context,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SizedBox(height: Insets.sm),

        // Most Costly Appliance
        if (mostCostly != null) ...[
          _buildApplianceCostItem(
            context,
            label: 'Most Costly',
            appliance: mostCostly['appliance'] as String,
            cost: mostCostly['cost'] as double? ?? 0.0,
            percentage: mostCostly['percentage'] as double?,
            kwh: mostCostly['kwh'] as double?,
            isHighCost: true,
          ),
          SizedBox(height: Insets.sm),
        ],

        // Least Costly Appliance
        if (leastCostly != null) ...[
          _buildApplianceCostItem(
            context,
            label: 'Least Costly',
            appliance: leastCostly['appliance'] as String,
            cost: leastCostly['cost'] as double? ?? 0.0,
            percentage: leastCostly['percentage'] as double?,
            kwh: leastCostly['kwh'] as double?,
            isHighCost: false,
          ),
          SizedBox(height: Insets.sm),
        ],

        // Expandable: All Appliances Breakdown
        if (appliancesByCost.isNotEmpty) ...[
          _buildExpandableApplianceBreakdown(context, appliancesByCost),
        ],
      ],
    );
  }

  Widget _buildApplianceCostItem(
    BuildContext context, {
    required String label,
    required String appliance,
    required double cost,
    double? percentage,
    double? kwh,
    required bool isHighCost,
  }) {
    return Container(
      padding: EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isHighCost
                  ? AppColor.accentRed.withAlpha((0.5 * 255).toInt())
                  : AppColor.accentGreen.withAlpha((0.5 * 255).toInt()),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: Colors.white70, fontSize: 10),
                ),
                SizedBox(height: 2),
                Text(
                  _formatApplianceName(appliance),
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                if (kwh != null) ...[
                  SizedBox(height: 2),
                  Text(
                    '${kwh.toStringAsFixed(2)} kWh',
                    style: ResponsiveText.caption(
                      context,
                    ).copyWith(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${cost.toStringAsFixed(2)}',
                style: ResponsiveText.body(context).copyWith(
                  color: isHighCost ? AppColor.accentRed : AppColor.accentGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (percentage != null) ...[
                SizedBox(height: 2),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: Colors.white70, fontSize: 10),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableApplianceBreakdown(
    BuildContext context,
    List<Map<String, dynamic>> appliancesByCost,
  ) {
    return _ExpandableApplianceBreakdown(
      appliancesByCost: appliancesByCost,
      formatApplianceName: _formatApplianceName,
    );
  }

  String _formatApplianceName(String applianceId) {
    // Convert appliance ID to readable name
    // e.g., "appliances_001" -> "Appliance 1"
    if (applianceId.startsWith('appliances_')) {
      final number = applianceId.replaceAll('appliances_', '');
      return 'Appliance $number';
    }
    return applianceId
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _ExpandableApplianceBreakdown extends StatefulWidget {
  final List<Map<String, dynamic>> appliancesByCost;
  final String Function(String) formatApplianceName;

  const _ExpandableApplianceBreakdown({
    required this.appliancesByCost,
    required this.formatApplianceName,
  });

  @override
  State<_ExpandableApplianceBreakdown> createState() =>
      _ExpandableApplianceBreakdownState();
}

class _ExpandableApplianceBreakdownState
    extends State<_ExpandableApplianceBreakdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.xm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Appliances Breakdown',
                  style: ResponsiveText.label(
                    context,
                  ).copyWith(color: Colors.white70, fontSize: 11),
                ),
                Icon(
                  _isExpanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_2,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          SizedBox(height: Insets.sm),
          ...widget.appliancesByCost.map((appliance) {
            final cost = appliance['cost'] as double? ?? 0.0;
            final percentage = appliance['percentage'] as double?;
            final kwh = appliance['kwh'] as double?;
            final isMostCostly = appliance == widget.appliancesByCost.first;
            final isLeastCostly = appliance == widget.appliancesByCost.last;

            return Padding(
              padding: EdgeInsets.only(bottom: Insets.xm),
              child: Container(
                padding: EdgeInsets.all(Insets.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.08 * 255).toInt()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (isMostCostly)
                            Icon(
                              Iconsax.arrow_up_1,
                              color: AppColor.accentRed,
                              size: 14,
                            )
                          else if (isLeastCostly)
                            Icon(
                              Iconsax.arrow_down_1,
                              color: AppColor.accentGreen,
                              size: 14,
                            )
                          else
                            SizedBox(width: 14),
                          SizedBox(width: Insets.xm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.formatApplianceName(
                                    appliance['appliance'] as String,
                                  ),
                                  style: ResponsiveText.caption(
                                    context,
                                  ).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (kwh != null) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    '${kwh.toStringAsFixed(2)} kWh',
                                    style: ResponsiveText.caption(
                                      context,
                                    ).copyWith(
                                      color: Colors.white60,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${cost.toStringAsFixed(2)}',
                          style: ResponsiveText.caption(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (percentage != null) ...[
                          SizedBox(height: 2),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: ResponsiveText.caption(
                              context,
                            ).copyWith(color: Colors.white60, fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}
