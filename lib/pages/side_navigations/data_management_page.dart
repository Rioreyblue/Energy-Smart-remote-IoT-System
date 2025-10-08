import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/settings_service.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = false;
  bool _isClearing = false;

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

                    // Clear Cache Section
                    _buildClearCacheSection(context),
                    SizedBox(height: Insets.lg),

                    // Storage Info Section
                    _buildStorageInfoSection(context),
                    SizedBox(height: Insets.lg),

                    // Data Export Section
                    _buildDataExportSection(context),
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
                  AppColor.accentRed.withOpacity(0.8),
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
                  '2.5 MB',
                  Iconsax.document,
                ),
              ),
              Expanded(
                child: _buildStorageItem(
                  context,
                  'Cache',
                  '1.2 MB',
                  Iconsax.folder_2,
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
                  'Readings',
                  '0.8 MB',
                  Iconsax.document_text,
                ),
              ),
              Expanded(
                child: _buildStorageItem(
                  context,
                  'Settings',
                  '0.1 MB',
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

          ElevatedButton.icon(
            onPressed: () {
              // Navigate to export page
              Navigator.pushNamed(context, '/exportUsageData');
            },
            icon: Icon(Iconsax.export_1, color: Colors.white),
            label: Text(
              'Export Data',
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
        ],
      ),
    );
  }
}
