import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/predictive_dataset_service.dart';
import 'package:exercise_app/services/prediction_service.dart';
import 'package:exercise_app/services/appliance_alias_service.dart';
import 'package:exercise_app/utils/snackbar_utils.dart';
import 'package:exercise_app/models/prediction_result_model.dart';
import 'package:exercise_app/utils/monitoring_prediction_utils.dart';

/// Helper class for theme-aware colors in PredictiveConsumptionCard
class _PredictiveCardColors {
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color tertiaryTextColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color iconColor;
  final List<Color> gradientColors;
  final Color shadowColor;

  _PredictiveCardColors({
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.tertiaryTextColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.iconColor,
    required this.gradientColors,
    required this.shadowColor,
  });

  factory _PredictiveCardColors.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _PredictiveCardColors(
      primaryTextColor: isDark ? AppColor.textPrimaryDark : Colors.white,
      secondaryTextColor: isDark ? AppColor.textSecondaryDark : Colors.white70,
      tertiaryTextColor:
          isDark ? AppColor.textSecondaryDark.withAlpha(200) : Colors.white60,
      backgroundColor:
          isDark
              ? AppColor.surfaceDark
              : AppColor.accentGreen.withAlpha((0.95 * 255).toInt()),
      surfaceColor:
          isDark
              ? AppColor.primaryDark.withAlpha((0.3 * 255).toInt())
              : Colors.white.withAlpha((0.2 * 255).toInt()),
      borderColor:
          isDark
              ? AppColor.textSecondaryDark.withAlpha((0.5 * 255).toInt())
              : Colors.white.withAlpha((0.3 * 255).toInt()),
      iconColor: isDark ? AppColor.textPrimaryDark : Colors.white,
      gradientColors:
          isDark
              ? [
                AppColor.primaryDark,
                AppColor.accentGreen.withAlpha((0.6 * 255).toInt()),
              ]
              : [AppColor.accentGreen, AppColor.lowConsumption],
      shadowColor:
          isDark
              ? Colors.black.withAlpha((0.3 * 255).toInt())
              : Colors.black.withAlpha((0.1 * 255).toInt()),
    );
  }
}

class PredictiveConsumptionCard extends StatefulWidget {
  final String period; // 'Day', 'Week', or 'Month'

  const PredictiveConsumptionCard({super.key, this.period = 'Month'});

  @override
  State<PredictiveConsumptionCard> createState() =>
      _PredictiveConsumptionCardState();
}

class _PredictiveConsumptionCardState extends State<PredictiveConsumptionCard> {
  final PredictiveDatasetService _datasetService = PredictiveDatasetService();
  final PredictionService _predictionService = PredictionService();
  final ApplianceAliasService _aliasService = ApplianceAliasService();
  PredictionResultModel? _currentPrediction;
  bool _isGeneratingPrediction = false;
  Map<String, String> _applianceAliases = {};

  @override
  void initState() {
    super.initState();
    _datasetService.initialize();
    _loadLatestPrediction();
    _loadApplianceAliases();
    _datasetService.addListener(_onDatasetChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh aliases when page becomes visible again (e.g., after renaming)
    _loadApplianceAliases();
  }

  Future<void> _loadApplianceAliases() async {
    try {
      final aliases = await _aliasService.getAliases();
      if (mounted) {
        setState(() {
          _applianceAliases = aliases;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _applianceAliases = {};
        });
      }
    }
  }

  @override
  void didUpdateWidget(PredictiveConsumptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Regenerate prediction when period changes
    if (oldWidget.period != widget.period && _datasetService.hasDataset) {
      _generatePrediction();
    }
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
      // Use the period from widget (Day, Week, or Month)
      final prediction = await _predictionService.generatePrediction(
        dataset: _datasetService.dataset,
        period: widget.period, // Pass the period parameter
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
    final cardColors = _PredictiveCardColors.fromContext(context);

    return ListenableBuilder(
      listenable: _datasetService,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: cardColors.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cardColors.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Builder(
                builder: (context) {
                  final cardColors = _PredictiveCardColors.fromContext(context);
                  return Row(
                    children: [
                      Icon(
                        Iconsax.chart_21,
                        color: cardColors.iconColor,
                        size: 24,
                      ),
                      SizedBox(width: Insets.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Predictive Consumption',
                              style: ResponsiveText.title(context).copyWith(
                                color: cardColors.primaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              _getPeriodDescription(widget.period),
                              style: ResponsiveText.caption(context).copyWith(
                                color: cardColors.secondaryTextColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Iconsax.refresh,
                          color: cardColors.iconColor,
                        ),
                        onPressed: _onRefreshPressed,
                        tooltip: 'Refresh Prediction',
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: Insets.lg),

              // Data Source Indicator (improved, consolidated)
              _buildDataSourceIndicator(context),
              SizedBox(height: Insets.md),

              // Prediction Summary
              Builder(
                builder: (context) {
                  final cardColors = _PredictiveCardColors.fromContext(context);
                  if (_isGeneratingPrediction) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(Insets.lg),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: cardColors.iconColor,
                            ),
                            SizedBox(height: Insets.md),
                            Text(
                              'Generating prediction...',
                              style: ResponsiveText.body(
                                context,
                              ).copyWith(color: cardColors.secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (_currentPrediction != null) {
                    return _buildPredictionSummary(
                      context,
                      _currentPrediction!,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataSourceIndicator(BuildContext context) {
    final cardColors = _PredictiveCardColors.fromContext(context);
    final dataSourceType = _datasetService.dataSource;
    final dataSourceInfo = _datasetService.getDataSourceInfo();
    final isOnline = dataSourceInfo['isOnline'] as bool? ?? false;
    final lastSyncTime = dataSourceInfo['lastSyncTime'] as DateTime?;
    final datasetSize = _datasetService.datasetSize;

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;
    String statusText;

    switch (dataSourceType) {
      case DataSourceType.cloud:
        badgeColor = AppColor.accentGreen;
        badgeIcon = Iconsax.cloud;
        badgeText = 'Cloud Data';
        statusText = 'Synced from Firestore';
        break;
      case DataSourceType.local:
        badgeColor = AppColor.mediumConsumption;
        badgeIcon = Iconsax.document_download;
        badgeText = 'Local Data';
        statusText = 'Offline backup';
        break;
      case DataSourceType.embedded:
        badgeColor = AppColor.disabled;
        badgeIcon = Iconsax.document;
        badgeText = 'Default Data';
        statusText = 'Sample dataset';
        break;
    }

    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cardColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withAlpha((0.3 * 255).toInt()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha((0.2 * 255).toInt()),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(badgeIcon, color: badgeColor, size: 20),
          ),
          SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      badgeText,
                      style: ResponsiveText.label(context).copyWith(
                        color: cardColors.primaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: Insets.sm),
                    // Online/Offline indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColor.accentGreen : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$datasetSize records',
                      style: ResponsiveText.body(context).copyWith(
                        color: cardColors.primaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: Insets.sm),
                    Text(
                      '•',
                      style: ResponsiveText.caption(
                        context,
                      ).copyWith(color: cardColors.secondaryTextColor),
                    ),
                    SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        statusText,
                        style: ResponsiveText.caption(context).copyWith(
                          color: cardColors.secondaryTextColor,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (lastSyncTime != null) ...[
                  SizedBox(height: 2),
                  Text(
                    'Updated ${_formatDate(lastSyncTime)}',
                    style: ResponsiveText.caption(context).copyWith(
                      color: cardColors.tertiaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (dataSourceType != DataSourceType.cloud)
            _datasetService.isLoading || _isGeneratingPrediction
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      cardColors.iconColor,
                    ),
                  ),
                )
                : IconButton(
                  icon: Icon(
                    Iconsax.refresh,
                    color: cardColors.iconColor,
                    size: 20,
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
    final cardColors = _PredictiveCardColors.fromContext(context);
    final costForecast = MonitoringPrediction.forecastCost(
      predictedKwh: prediction.predictedKwh,
    );

    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cardColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Predicted Consumption with Classification Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPeriodPredictionLabel(widget.period),
                      style: ResponsiveText.label(
                        context,
                      ).copyWith(color: cardColors.secondaryTextColor),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _getPeriodExplanation(widget.period),
                      style: ResponsiveText.caption(context).copyWith(
                        color: cardColors.tertiaryTextColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    prediction.formattedPredictedKwh,
                    style: ResponsiveText.stat(context).copyWith(
                      color: cardColors.primaryTextColor,
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
                        color: cardColors.borderColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          prediction.consumptionLevelIcon,
                          size: 14,
                          color: cardColors.primaryTextColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          prediction.consumptionLevel.toUpperCase(),
                          style: ResponsiveText.caption(context).copyWith(
                            color: cardColors.primaryTextColor,
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
          // Classification explanation - more user-friendly
          Container(
            padding: EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              color: cardColors.backgroundColor.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.info_circle,
                  color: cardColors.secondaryTextColor,
                  size: 14,
                ),
                SizedBox(width: Insets.xm),
                Expanded(
                  child: Text(
                    _getPeriodHelpText(widget.period),
                    style: ResponsiveText.caption(context).copyWith(
                      color: cardColors.secondaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Insets.sm),

          // Cost Range - clearer label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected Cost',
                    style: ResponsiveText.label(
                      context,
                    ).copyWith(color: cardColors.secondaryTextColor),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Estimate based on current rates',
                    style: ResponsiveText.caption(context).copyWith(
                      color: cardColors.tertiaryTextColor,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${costForecast['minCost']!.toStringAsFixed(2)} - ₱${costForecast['maxCost']!.toStringAsFixed(2)}',
                    style: ResponsiveText.stat(context).copyWith(
                      color: cardColors.primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Range estimate',
                    style: ResponsiveText.caption(context).copyWith(
                      color: cardColors.tertiaryTextColor,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Insets.sm),

          // Appliance Cost Analysis Section
          if (prediction.applianceCostBreakdown != null &&
              prediction.applianceCostBreakdown!.isNotEmpty) ...[
            SizedBox(height: Insets.md),
            Builder(
              builder: (context) {
                final cardColors = _PredictiveCardColors.fromContext(context);
                return Divider(color: cardColors.borderColor, thickness: 1);
              },
            ),
            SizedBox(height: Insets.sm),
            _buildApplianceCostAnalysis(context, prediction),
          ],

          // Confidence
          SizedBox(height: Insets.sm),
          Row(
            children: [
              Icon(
                Iconsax.shield_tick,
                color: cardColors.secondaryTextColor,
                size: 16,
              ),
              SizedBox(width: Insets.xm),
              Text(
                'Confidence: ${prediction.formattedConfidence}',
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: cardColors.secondaryTextColor),
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
        Builder(
          builder: (context) {
            final cardColors = _PredictiveCardColors.fromContext(context);
            return Row(
              children: [
                Icon(
                  Iconsax.info_circle,
                  color: cardColors.secondaryTextColor,
                  size: 16,
                ),
                SizedBox(width: Insets.xm),
                Text(
                  'Appliance Cost Analysis',
                  style: ResponsiveText.label(context).copyWith(
                    color: cardColors.primaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
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
    final cardColors = _PredictiveCardColors.fromContext(context);
    return Container(
      padding: EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: cardColors.backgroundColor.withAlpha((0.1 * 255).toInt()),
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
                  style: ResponsiveText.caption(context).copyWith(
                    color: cardColors.secondaryTextColor,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _formatApplianceName(appliance),
                  style: ResponsiveText.body(context).copyWith(
                    color: cardColors.primaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (kwh != null) ...[
                  SizedBox(height: 2),
                  Text(
                    '${kwh.toStringAsFixed(2)} kWh',
                    style: ResponsiveText.caption(context).copyWith(
                      color: cardColors.tertiaryTextColor,
                      fontSize: 10,
                    ),
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
                  style: ResponsiveText.caption(context).copyWith(
                    color: cardColors.secondaryTextColor,
                    fontSize: 10,
                  ),
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
    // First check if there's a custom alias/display name from Quick Controls
    if (_applianceAliases.containsKey(applianceId) &&
        _applianceAliases[applianceId]!.isNotEmpty) {
      return _applianceAliases[applianceId]!;
    }

    // Fallback to default formatting
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

  /// Get user-friendly period description
  String _getPeriodDescription(String period) {
    switch (period.toLowerCase()) {
      case 'day':
        return 'Forecasting tomorrow\'s consumption';
      case 'week':
        return 'Forecasting next week\'s consumption';
      case 'month':
      default:
        return 'Forecasting next month\'s consumption';
    }
  }

  /// Get prediction label for the period
  String _getPeriodPredictionLabel(String period) {
    switch (period.toLowerCase()) {
      case 'day':
        return 'Predicted Tomorrow';
      case 'week':
        return 'Predicted Next Week';
      case 'month':
      default:
        return 'Predicted Next Month';
    }
  }

  /// Get explanation text for the period
  String _getPeriodExplanation(String period) {
    switch (period.toLowerCase()) {
      case 'day':
        return 'Based on your daily usage patterns';
      case 'week':
        return 'Based on your weekly usage patterns';
      case 'month':
      default:
        return 'Based on your monthly usage history';
    }
  }

  /// Get help text explaining the prediction
  String _getPeriodHelpText(String period) {
    switch (period.toLowerCase()) {
      case 'day':
        return 'This prediction estimates tomorrow\'s energy consumption based on your historical daily patterns, helping you plan ahead.';
      case 'week':
        return 'This prediction estimates next week\'s energy consumption based on your historical weekly patterns, helping you manage your energy budget.';
      case 'month':
      default:
        return 'This prediction estimates next month\'s consumption using your historical data, industry benchmarks, and current usage patterns.';
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
    final cardColors = _PredictiveCardColors.fromContext(context);
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
              color: cardColors.backgroundColor.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Appliances Breakdown',
                  style: ResponsiveText.label(context).copyWith(
                    color: cardColors.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
                Icon(
                  _isExpanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_2,
                  color: cardColors.secondaryTextColor,
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
              child: Builder(
                builder: (context) {
                  final cardColors = _PredictiveCardColors.fromContext(context);
                  return Container(
                    padding: EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: cardColors.backgroundColor.withAlpha(
                        (0.08 * 255).toInt(),
                      ),
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
                                        color: cardColors.primaryTextColor,
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
                                          color: cardColors.tertiaryTextColor,
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
                                color: cardColors.primaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (percentage != null) ...[
                              SizedBox(height: 2),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: ResponsiveText.caption(context).copyWith(
                                  color: cardColors.tertiaryTextColor,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}
