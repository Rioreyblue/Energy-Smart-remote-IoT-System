import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/export_service.dart';
import 'package:exercise_app/services/goals_service.dart';
import 'package:exercise_app/models/goals_model.dart';
import 'package:exercise_app/utils/permission_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:go_router/go_router.dart';

class ExportUsageDataPage extends StatefulWidget {
  const ExportUsageDataPage({super.key});

  @override
  State<ExportUsageDataPage> createState() => _ExportUsageDataPageState();
}

class _ExportUsageDataPageState extends State<ExportUsageDataPage> {
  final ExportService _exportService = ExportService();
  final GoalsService _goalsService = GoalsService();

  ExportFormat _selectedFormat = ExportFormat.csv;
  bool _isLoading = false;
  bool _isExporting = false;
  List<MeterReadingModel> _readingHistory = [];
  ExportStatistics? _statistics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final historyResult = await _goalsService.getMeterReadingsHistory();
      if (historyResult.isSuccess) {
        setState(() {
          _readingHistory = historyResult.data!;
          _statistics = _exportService.getExportStatistics(historyResult.data!);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${historyResult.error}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportData() async {
    if (_readingHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data available to export'),
          backgroundColor: AppColor.accentRed,
        ),
      );
      return;
    }

    // Check and request permissions
    final hasPermission = await PermissionHelper.isStoragePermissionGranted();
    if (!hasPermission) {
      final granted = await PermissionHelper.showPermissionRationale(context);
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Storage permission is required to export files. Please grant permission in app settings.',
            ),
            backgroundColor: AppColor.accentRed,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => PermissionHelper.openAppSettingsPage(),
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isExporting = true);

    try {
      final fileName = 'energy_usage_${DateTime.now().millisecondsSinceEpoch}';
      final result = await _exportService.exportData(
        data: _readingHistory,
        format: _selectedFormat,
        fileName: fileName,
      );

      if (result.success && result.filePath != null) {
        _showExportSuccessDialog(result.filePath!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showExportSuccessDialog(String filePath) {
    // Extract Downloads folder path for display
    String displayPath = filePath;
    if (filePath.contains('/Download/')) {
      displayPath = 'Download/${filePath.split('/Download/').last}';
    } else if (filePath.contains('Download')) {
      displayPath =
          'Download/${filePath.split('Download').last.replaceFirst('/', '')}';
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Iconsax.tick_circle,
                  color: AppColor.accentGreen,
                  size: 24,
                ),
                SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'Export Successful',
                    style: ResponsiveText.stat(context),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data has been exported successfully!',
                  style: ResponsiveText.body(context),
                ),
                SizedBox(height: Insets.md),
                Text('File saved to:', style: ResponsiveText.label(context)),
                SizedBox(height: Insets.sm),
                Container(
                  padding: EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: AppColor.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColor.disabled),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.folder,
                        size: 16,
                        color: AppColor.accentGreen,
                      ),
                      SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          displayPath,
                          style: ResponsiveText.caption(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: ResponsiveText.body(context)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final result = await OpenFilex.open(filePath);
                    if (result.type != ResultType.done) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not open file: ${result.message}',
                          ),
                          backgroundColor: AppColor.accentRed,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening file: $e'),
                        backgroundColor: AppColor.accentRed,
                      ),
                    );
                  }
                },
                icon: Icon(Iconsax.export_1, size: 16),
                label: Text('Open File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Export Usage Data', style: ResponsiveText.stat(context)),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_1),
          onPressed: () => context.go('/home'),
          color: Colors.white,
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColor.accentGreen),
                    SizedBox(height: Insets.md),
                    Text(
                      'Loading data...',
                      style: ResponsiveText.body(context),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Iconsax.export_1,
                          color: AppColor.accentGreen,
                          size: 28,
                        ),
                        SizedBox(width: Insets.sm),
                        Text(
                          'Export Energy Usage Data',
                          style: ResponsiveText.stat(context),
                        ),
                      ],
                    ),
                    SizedBox(height: Insets.sm),
                    Text(
                      'Export your energy consumption history and billing data in various formats.',
                      style: ResponsiveText.body(context),
                    ),
                    SizedBox(height: Insets.lg),

                    // Statistics Card
                    if (_statistics != null) ...[
                      _buildStatisticsCard(context),
                      SizedBox(height: Insets.lg),
                    ],

                    // Export Format Selection
                    _buildFormatSelectionCard(context),
                    SizedBox(height: Insets.lg),

                    // Export Button
                    _buildExportButton(context),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatisticsCard(BuildContext context) {
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
              Icon(Iconsax.chart_2, color: AppColor.accentGreen, size: 24),
              SizedBox(width: Insets.sm),
              Text('Export Statistics', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total Readings',
                  '${_statistics!.totalReadings}',
                  Iconsax.document,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total Consumption',
                  '${_statistics!.totalConsumption.toStringAsFixed(1)} kWh',
                  Iconsax.flash_1,
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total Bill',
                  '₱${_statistics!.totalBill.toStringAsFixed(2)}',
                  Iconsax.money,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Average Usage',
                  '${_statistics!.averageConsumption.toStringAsFixed(1)} kWh',
                  Iconsax.chart_1,
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),

          Text(
            'Date Range: ${_statistics!.dateRange}',
            style: ResponsiveText.caption(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColor.accentGreen.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColor.accentGreen, size: 20),
          SizedBox(height: Insets.sm),
          Text(
            value,
            style: ResponsiveText.body(context).copyWith(
              fontWeight: FontWeight.bold,
              color: AppColor.accentGreen,
            ),
          ),
          SizedBox(height: Insets.xm),
          Text(
            label,
            style: ResponsiveText.caption(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelectionCard(BuildContext context) {
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
              Icon(Iconsax.document, color: AppColor.primary, size: 24),
              SizedBox(width: Insets.sm),
              Text('Export Format', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Choose your preferred export format:',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          // Format Options
          Row(
            children: [
              Expanded(
                child: _buildFormatOption(
                  context,
                  'CSV',
                  'Spreadsheet format for data analysis',
                  Iconsax.document_text,
                  ExportFormat.csv,
                ),
              ),
              SizedBox(width: Insets.md),
              Expanded(
                child: _buildFormatOption(
                  context,
                  'PDF',
                  'Formatted report for printing',
                  Iconsax.document,
                  ExportFormat.pdf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    ExportFormat format,
  ) {
    final isSelected = _selectedFormat == format;

    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: Container(
        padding: EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.primary.withAlpha(26) : AppColor.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColor.primary : AppColor.disabled,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColor.primary : AppColor.disabled,
              size: 32,
            ),
            SizedBox(height: Insets.sm),
            Text(
              title,
              style: ResponsiveText.body(context).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColor.primary : AppColor.disabled,
              ),
            ),
            SizedBox(height: Insets.xm),
            Text(
              description,
              style: ResponsiveText.caption(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColor.accentGreen, AppColor.lowConsumption],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: _isExporting || _readingHistory.isEmpty ? null : _exportData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: Insets.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isExporting
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: Insets.sm),
                    Text(
                      'Exporting...',
                      style: ResponsiveText.body(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.export_1, color: Colors.white, size: 20),
                    SizedBox(width: Insets.sm),
                    Text(
                      'Export as ${_selectedFormat.name.toUpperCase()}',
                      style: ResponsiveText.body(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
