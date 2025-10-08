import 'package:exercise_app/constants/constant.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/components/monitoring_header_card.dart';
import 'package:exercise_app/components/monitoring_chart_card.dart';
import 'package:exercise_app/components/monitoring_status_card.dart';
import 'package:exercise_app/utils/monitoring_prediction_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  String selectedPeriod = 'Week';
  final List<String> periods = ['Day', 'Week', 'Month', 'Year'];
  bool _isLoading = false;

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
                  SizedBox(height: Insets.md),
                  // Predictive Consumption Feature
                  _buildPredictionSection(context),
                  SizedBox(height: Insets.md),
                  // Data Import/Export Feature
                  _buildImportExportSection(context),
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

  Widget _buildPredictionSection(BuildContext context) {
    // Example: Use MonitoringPrediction with dummy data
    final historical = [
      180.5,
      195.2,
      170.8,
      200.1,
      210.0,
      205.5,
      198.0,
      215.3,
      220.1,
      210.7,
      205.0,
      199.8,
    ];
    final prediction = MonitoringPrediction.predictNextPeriod(historical);
    final double predicted = prediction['predicted'] ?? 0;
    final double previous = prediction['previous'] ?? 0;
    final double percentChange =
        previous == 0 ? 0 : ((predicted - previous) / previous) * 100;
    final bool isHigher = predicted > previous;
    final String percentText =
        '${percentChange.abs().toStringAsFixed(1)}% ${isHigher ? 'higher' : 'lower'} than last month';
    final String suggestion =
        isHigher
            ? 'Consider reducing AC usage or unplugging idle devices to save energy.'
            : 'Great job! Your consumption is trending down.';
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
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Predictive Consumption', style: ResponsiveText.stat(context)),
          SizedBox(height: Insets.md),
          Row(
            children: [
              // Icon(Iconsax.present, color: AppColor.accentGreen, size: 24),
              // SizedBox(width: Insets.md),
              Text('Expected:', style: ResponsiveText.stat(context)),
              SizedBox(width: Insets.sm),
              Text(
                '${predicted.toStringAsFixed(1)} kWh',
                style: ResponsiveText.body(
                  context,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: Insets.lg),
            ],
          ),
          Row(
            children: [
              // Icon(Iconsax.previous4, color: AppColor.accentGreen, size: 24),
              Text('Previous:', style: ResponsiveText.body(context)),
              SizedBox(width: Insets.sm),
              Text(
                '${previous.toStringAsFixed(1)} kWh',
                style: ResponsiveText.body(
                  context,
                ).copyWith(color: AppColor.disabled),
              ),
            ],
          ),
          SizedBox(height: Insets.sm),
          Row(
            children: [
              Icon(
                isHigher ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                color: isHigher ? AppColor.accentRed : AppColor.accentGreen,
                size: 18,
              ),
              SizedBox(width: Insets.sm),
              Text(
                percentText,
                style: ResponsiveText.label(context).copyWith(
                  color: isHigher ? AppColor.accentRed : AppColor.accentGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          Container(
            padding: EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color:
                  isHigher
                      ? AppColor.accentRed.withAlpha(26)
                      : AppColor.accentGreen.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.lamp_on,
                  color: isHigher ? AppColor.accentRed : AppColor.accentGreen,
                  size: 18,
                ),
                SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(suggestion, style: ResponsiveText.body(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportExportSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(Iconsax.import, color: AppColor.primary),
            label: Text('Import Data', style: ResponsiveText.body(context)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.surface,
              foregroundColor: AppColor.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              setState(() => _isLoading = true);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json', 'csv'],
                );
                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final content = await file.readAsString();
                  // For now, just check if file is not empty
                  if (content.isNotEmpty) {
                    // TODO: Parse and use data
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Import successful!'),
                        backgroundColor: AppColor.accentGreen,
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Import failed: File is empty.'),
                        backgroundColor: AppColor.accentRed,
                      ),
                    );
                  }
                } else {
                  // User canceled
                }
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Import failed: ${e.toString()}'),
                    backgroundColor: AppColor.accentRed,
                  ),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            },
          ),
        ),
        SizedBox(width: Insets.md),
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(Iconsax.export, color: AppColor.primary),
            label: Text('Export Data', style: ResponsiveText.body(context)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.surface,
              foregroundColor: AppColor.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              setState(() => _isLoading = true);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                // Mock data to export
                final data = [
                  {'date': '2024-05-01', 'usage': 6.1},
                  {'date': '2024-05-02', 'usage': 5.8},
                  {'date': '2024-05-03', 'usage': 7.2},
                ];
                String jsonString = jsonEncode(data);
                Directory? directory;
                if (Platform.isAndroid) {
                  directory = await getExternalStorageDirectory();
                } else {
                  directory = await getApplicationDocumentsDirectory();
                }
                String fileName =
                    'energy_data_${DateTime.now().millisecondsSinceEpoch}.json';
                String filePath = '${directory!.path}/$fileName';
                File file = File(filePath);
                await file.writeAsString(jsonString);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Exported to $fileName'),
                    backgroundColor: AppColor.accentGreen,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Export failed: ${e.toString()}'),
                    backgroundColor: AppColor.accentRed,
                  ),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            },
          ),
        ),
      ],
    );
  }
}
