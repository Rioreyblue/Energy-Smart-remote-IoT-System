import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/settings_service.dart';
import 'package:exercise_app/services/local_storage_service.dart';
import 'package:exercise_app/services/goals_service.dart';
import 'package:exercise_app/services/export_service.dart';
import 'package:exercise_app/utils/permission_helper.dart';
import 'package:exercise_app/models/goals_model.dart';
import 'package:go_router/go_router.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  final SettingsService _settingsService = SettingsService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final GoalsService _goalsService = GoalsService();
  final ExportService _exportService = ExportService();

  bool _isLoading = false;
  bool _isClearing = false;
  bool _isClearingLocalStorage = false;
  bool _isExportingAll = false;
  Map<String, int> _storageSizes = {};

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    try {
      final sizes = await _localStorageService.getStorageSize();
      setState(() {
        _storageSizes = sizes;
      });
    } catch (e) {
      // Handle error silently
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAppCache() async {
    setState(() => _isClearing = true);

    try {
      // Simulate cache clearing process
      await Future.delayed(Duration(seconds: 2));

      // Clear settings cache
      await _settingsService.resetSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('App cache cleared successfully!'),
            backgroundColor: AppColor.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Future<void> _showClearCacheDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Iconsax.warning_2, color: AppColor.accentRed, size: 24),
                SizedBox(width: Insets.sm),
                Text('Clear App Cache', style: ResponsiveText.stat(context)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will clear all cached data including:',
                  style: ResponsiveText.body(context),
                ),
                SizedBox(height: Insets.md),
                _buildWarningItem(context, 'Settings and preferences'),
                _buildWarningItem(context, 'User data and readings'),
                _buildWarningItem(context, 'Temporary files and cache'),
                SizedBox(height: Insets.md),
                Text(
                  'This action cannot be undone. Are you sure you want to continue?',
                  style: ResponsiveText.body(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColor.accentRed,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentRed,
                  foregroundColor: Colors.white,
                ),
                child: Text('Clear Cache', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _clearAppCache();
    }
  }

  Widget _buildWarningItem(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Icon(Iconsax.close_circle, color: AppColor.accentRed, size: 16),
          SizedBox(width: Insets.sm),
          Text(text, style: ResponsiveText.body(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Data Management', style: ResponsiveText.stat(context)),
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
                    Text('Loading...', style: ResponsiveText.body(context)),
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
                          Iconsax.trash,
                          color: AppColor.accentRed,
                          size: 28,
                        ),
                        SizedBox(width: Insets.sm),
                        Text(
                          'Data Management',
                          style: ResponsiveText.stat(context),
                        ),
                      ],
                    ),
                    SizedBox(height: Insets.sm),
                    Text(
                      'Manage your app data, cache, and storage settings.',
                      style: ResponsiveText.body(context),
                    ),
                    SizedBox(height: Insets.lg),

                    // Storage Info Section
                    _buildStorageInfoSection(context),
                    SizedBox(height: Insets.lg),

                    // Data Export Section
                    _buildDataExportSection(context),
                    SizedBox(height: Insets.lg),

                    // Local Storage Section
                    _buildLocalStorageSection(context),
                    SizedBox(height: Insets.lg),

                    // Clear Cache Section
                    _buildClearCacheSection(context),
                  ],
                ),
              ),
    );
  }

  Widget _buildClearCacheSection(BuildContext context) {
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
              Icon(Iconsax.trash, color: AppColor.accentRed, size: 24),
              SizedBox(width: Insets.sm),
              Text('Clear App Cache', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Remove all cached data, temporary files, and reset app state to improve performance.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColor.accentRed,
                  AppColor.accentRed.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isClearing ? null : _showClearCacheDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: Insets.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isClearing
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            'Clearing Cache...',
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
                          Icon(Iconsax.trash, color: Colors.white, size: 20),
                          SizedBox(width: Insets.sm),
                          Text(
                            'Clear App Cache',
                            style: ResponsiveText.body(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfoSection(BuildContext context) {
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
              Icon(Iconsax.folder, color: AppColor.primary, size: 24),
              SizedBox(width: Insets.sm),
              Text('Storage Information', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),

          Row(
            children: [
              Expanded(
                child: _buildStorageItem(
                  context,
                  'App Data',
                  LocalStorageService.formatBytes(_storageSizes['Total'] ?? 0),
                  Iconsax.document,
                ),
              ),
              Expanded(
                child: _buildStorageItem(
                  context,
                  'Meter Readings',
                  LocalStorageService.formatBytes(
                    _storageSizes['meter_readings.json'] ?? 0,
                  ),
                  Iconsax.document_text,
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),

          Row(
            children: [
              Expanded(
                child: _buildStorageItem(
                  context,
                  'Appliances',
                  LocalStorageService.formatBytes(
                    _storageSizes['appliances.json'] ?? 0,
                  ),
                  Iconsax.folder_2,
                ),
              ),
              Expanded(
                child: _buildStorageItem(
                  context,
                  'Settings',
                  LocalStorageService.formatBytes(
                    _storageSizes['SharedPreferences'] ?? 0,
                  ),
                  Iconsax.setting_2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(
    BuildContext context,
    String label,
    String size,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColor.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColor.primary, size: 20),
          SizedBox(height: Insets.sm),
          Text(
            size,
            style: ResponsiveText.body(
              context,
            ).copyWith(fontWeight: FontWeight.bold, color: AppColor.primary),
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

  Widget _buildDataExportSection(BuildContext context) {
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
              Icon(Iconsax.export_1, color: AppColor.accentGreen, size: 24),
              SizedBox(width: Insets.sm),
              Text('Data Export', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Export your data before clearing cache to avoid data loss.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          // Export Usage Data Button
          ElevatedButton.icon(
            onPressed: () {
              context.go('/exportUsageData');
            },
            icon: Icon(Iconsax.export_1, color: Colors.white),
            label: Text(
              'Export Usage Data',
              style: ResponsiveText.body(
                context,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.accentGreen,
              padding: EdgeInsets.symmetric(
                vertical: Insets.md,
                horizontal: Insets.lg,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(height: Insets.md),

          // Export All Data Button
          OutlinedButton.icon(
            onPressed: _isExportingAll ? null : _exportAllData,
            icon: Icon(Iconsax.document_download, color: AppColor.accentGreen),
            label:
                _isExportingAll
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColor.accentGreen,
                      ),
                    )
                    : Text(
                      'Export All Data',
                      style: ResponsiveText.body(context).copyWith(
                        color: AppColor.accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColor.accentGreen, width: 2),
              padding: EdgeInsets.symmetric(
                vertical: Insets.md,
                horizontal: Insets.lg,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAllData() async {
    // Request permissions
    final hasPermission = await PermissionHelper.isStoragePermissionGranted();
    if (!hasPermission) {
      final granted = await PermissionHelper.showPermissionRationale(context);
      if (!granted) {
        return;
      }
    }

    setState(() => _isExportingAll = true);

    try {
      // Get all data
      final readingsResult = await _goalsService.getMeterReadingsHistory();
      final readings =
          readingsResult.isSuccess && readingsResult.data != null
              ? readingsResult.data!
              : <MeterReadingModel>[];

      if (readings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No data available to export'),
            backgroundColor: AppColor.accentRed,
          ),
        );
        return;
      }

      // Export as CSV (default)
      final fileName =
          'energy_smart_all_data_${DateTime.now().millisecondsSinceEpoch}';
      final result = await _exportService.exportData(
        data: readings,
        format: ExportFormat.csv,
        fileName: fileName,
      );

      if (result.success && result.filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All data exported successfully to Downloads folder!',
            ),
            backgroundColor: AppColor.accentGreen,
            duration: const Duration(seconds: 3),
          ),
        );
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
      setState(() => _isExportingAll = false);
    }
  }

  Future<void> _clearLocalStorage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Iconsax.warning_2, color: AppColor.accentRed, size: 24),
                SizedBox(width: Insets.sm),
                Text(
                  'Clear Local Storage',
                  style: ResponsiveText.stat(context),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete all locally stored data including:',
                  style: ResponsiveText.body(context),
                ),
                SizedBox(height: Insets.md),
                _buildWarningItem(context, 'Meter readings'),
                _buildWarningItem(context, 'Appliance data'),
                _buildWarningItem(context, 'User profile cache'),
                SizedBox(height: Insets.md),
                Text(
                  'This action cannot be undone. Make sure to export your data first!',
                  style: ResponsiveText.body(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColor.accentRed,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentRed,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Clear Storage',
                  style: ResponsiveText.body(context),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isClearingLocalStorage = true);
      try {
        final success = await _localStorageService.clearLocalStorage();
        if (success && mounted) {
          await _loadStorageInfo(); // Refresh storage info
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Local storage cleared successfully!'),
              backgroundColor: AppColor.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing storage: $e'),
              backgroundColor: AppColor.accentRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isClearingLocalStorage = false);
        }
      }
    }
  }

  Widget _buildLocalStorageSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColor.mediumConsumption, width: 4),
          right: BorderSide(color: AppColor.mediumConsumption, width: 4),
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
                Iconsax.document_download,
                color: AppColor.mediumConsumption,
                size: 24,
              ),
              SizedBox(width: Insets.sm),
              Text('Local Storage', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Manage locally stored data on your device. Clear local storage to free up space.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColor.mediumConsumption,
                  AppColor.mediumConsumption.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isClearingLocalStorage ? null : _clearLocalStorage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: Insets.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isClearingLocalStorage
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            'Clearing Storage...',
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
                          Icon(Iconsax.trash, color: Colors.white, size: 20),
                          SizedBox(width: Insets.sm),
                          Text(
                            'Clear Local Storage',
                            style: ResponsiveText.body(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
