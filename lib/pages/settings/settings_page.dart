import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/components/header.dart';
import 'package:exercise_app/services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Services
  final SettingsService _settingsService = SettingsService();

  // User Profile State
  String _userName = 'Rey Francisco';
  String _userEmail = 'rey.francisco@example.com';
  String _userPhone = '+63 963 559 5848';
  String _userAddress = '123 Energy Street, Metro Manila';

  // Settings State
  bool _pushNotifications = true;
  double _alertThreshold = 80.0;
  String _energyRate = '12.50';
  String _themeMode = 'system';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load existing settings
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Load settings
      await _settingsService.loadSettings();

      setState(() {
        _pushNotifications = _settingsService.getPushNotifications();
        _alertThreshold = _settingsService.getAlertThreshold();
        _energyRate = _settingsService.getDefaultRate().toString();
        _themeMode = _settingsService.getThemeMode();
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _responsiveFontSize(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    return base * (width / 375.0).clamp(0.85, 1.2);
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
                      'Loading settings...',
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
                    Header(
                      username: _userName,
                      responsiveFontSize: _responsiveFontSize,
                    ),
                    SizedBox(height: Insets.lg),

                    // Account Section
                    _buildSectionHeader(context, 'Account', Iconsax.user),
                    _buildAccountSection(context),
                    SizedBox(height: Insets.lg),

                    // Energy Section
                    _buildSectionHeader(context, 'Energy', Iconsax.flash_1),
                    _buildEnergySection(context),
                    SizedBox(height: Insets.lg),

                    // App Section
                    _buildSectionHeader(context, 'App', Iconsax.setting_2),
                    _buildAppSection(context),
                    SizedBox(height: Insets.lg),

                    // Support Section
                    _buildSectionHeader(
                      context,
                      'Support',
                      Iconsax.info_circle,
                    ),
                    _buildSupportSection(context),
                    SizedBox(height: Insets.lg),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: [
          Icon(icon, color: AppColor.accentGreen, size: 20),
          SizedBox(width: Insets.sm),
          Text(
            title,
            style: ResponsiveText.stat(context).copyWith(
              color: AppColor.accentGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
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
        children: [
          _buildListTile(
            context,
            'Edit Profile',
            'Update name, email, phone, address',
            Iconsax.user_edit,
            () => _showEditProfileDialog(context),
          ),
          _buildDivider(),
          _buildListTile(
            context,
            'Change Password',
            'Reset password and security settings',
            Iconsax.lock,
            () => _showChangePasswordDialog(context),
          ),
          _buildDivider(),
          _buildListTile(
            context,
            'Logout',
            'Sign out of your account',
            Iconsax.logout,
            () => _showLogoutDialog(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEnergySection(BuildContext context) {
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
        children: [
          _buildListTile(
            context,
            'Energy Rate (per kWh)',
            '₱$_energyRate per kWh',
            Iconsax.money,
            () => _showEnergyRateDialog(context),
          ),
          _buildDivider(),
          _buildListTile(
            context,
            'Alert Threshold',
            '${_alertThreshold.toInt()}% of energy target',
            Iconsax.warning_2,
            () => _showAlertThresholdDialog(context),
          ),
          _buildDivider(),
          _buildListTile(
            context,
            'Data Export / History',
            'Export usage and billing history',
            Iconsax.export,
            () => _showDataExportDialog(context),
          ),
          _buildDivider(),
          _buildListTile(
            context,
            'Manage Devices',
            'Add or remove IoT devices',
            Iconsax.devices,
            () => _showDeviceManagementDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSection(BuildContext context) {
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
        children: [
          _buildSwitchTile(
            context,
            'Push Notifications',
            'Receive alerts and updates',
            Iconsax.notification,
            _pushNotifications,
            (value) => _updatePushNotifications(value),
          ),
          _buildDivider(),
          _buildListTile(
            context,
            'Theme Mode',
            _getThemeModeText(_themeMode),
            Iconsax.moon,
            () => _showThemeDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
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
        children: [
          _buildListTile(
            context,
            'About App',
            'Version 1.0.0 • EnergySmart',
            Iconsax.info_circle,
            () => _showAboutDialog(context),
          ),
          _buildDivider(),
          _buildListTile(
            context,
            'Help & Support',
            'Get help and contact support',
            Iconsax.message,
            () => _navigateToSupport(),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap, {
    bool isReadOnly = false,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(Insets.sm),
        decoration: BoxDecoration(
          color:
              isDestructive
                  ? AppColor.accentRed.withAlpha(26)
                  : AppColor.accentGreen.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? AppColor.accentRed : AppColor.accentGreen,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: ResponsiveText.body(context).copyWith(
          fontWeight: FontWeight.w600,
          color: isDestructive ? AppColor.accentRed : null,
        ),
      ),
      subtitle: Text(subtitle, style: ResponsiveText.caption(context)),
      trailing:
          isReadOnly
              ? Icon(Iconsax.lock_1, color: AppColor.disabled, size: 16)
              : Icon(Iconsax.arrow_right_3, color: AppColor.disabled, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(Insets.sm),
        decoration: BoxDecoration(
          color: AppColor.accentGreen.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColor.accentGreen, size: 20),
      ),
      title: Text(
        title,
        style: ResponsiveText.body(
          context,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: ResponsiveText.caption(context)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColor.accentGreen,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: Insets.sm),
      height: 1,
      color: AppColor.disabled.withAlpha(51),
    );
  }

  // Helper methods for display text
  String _getThemeModeText(String mode) {
    switch (mode) {
      case 'light':
        return 'Light Mode';
      case 'dark':
        return 'Dark Mode';
      case 'system':
        return 'System Default';
      default:
        return 'System Default';
    }
  }

  // Settings update methods
  Future<void> _updatePushNotifications(bool value) async {
    setState(() => _pushNotifications = value);
    await _settingsService.setPushNotifications(value);
  }

  // Dialog methods
  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Edit Profile', style: ResponsiveText.stat(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    'Name',
                    _userName,
                    (value) => _userName = value,
                  ),
                  SizedBox(height: Insets.md),
                  _buildTextField(
                    'Email',
                    _userEmail,
                    (value) => _userEmail = value,
                  ),
                  SizedBox(height: Insets.md),
                  _buildTextField(
                    'Phone',
                    _userPhone,
                    (value) => _userPhone = value,
                  ),
                  SizedBox(height: Insets.md),
                  _buildTextField(
                    'Address',
                    _userAddress,
                    (value) => _userAddress = value,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: AppColor.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: Text('Save', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String) onChanged,
  ) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: onChanged,
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Change Password', style: ResponsiveText.stat(context)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('Current Password', '', (value) {}),
                SizedBox(height: Insets.md),
                _buildTextField('New Password', '', (value) {}),
                SizedBox(height: Insets.md),
                _buildTextField('Confirm Password', '', (value) {}),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password changed successfully!'),
                      backgroundColor: AppColor.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: Text('Update', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  void _showEnergyRateDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: _energyRate,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Energy Rate', style: ResponsiveText.stat(context)),
            content: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Rate per kWh (₱)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixText: '₱',
              ),
              keyboardType: TextInputType.number,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _energyRate = controller.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Energy rate updated to ₱$_energyRate'),
                      backgroundColor: AppColor.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: Text('Save', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  void _showAlertThresholdDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Alert Threshold', style: ResponsiveText.stat(context)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current threshold: ${_alertThreshold.toInt()}%',
                  style: ResponsiveText.body(context),
                ),
                SizedBox(height: Insets.md),
                Slider(
                  value: _alertThreshold,
                  min: 50,
                  max: 100,
                  divisions: 10,
                  label: '${_alertThreshold.toInt()}%',
                  onChanged: (value) {
                    setState(() => _alertThreshold = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Alert threshold set to ${_alertThreshold.toInt()}%',
                      ),
                      backgroundColor: AppColor.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: Text('Save', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  void _showDataExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Export Data', style: ResponsiveText.stat(context)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose export format:',
                  style: ResponsiveText.body(context),
                ),
                SizedBox(height: Insets.md),
                ListTile(
                  leading: Icon(Iconsax.document, color: AppColor.accentGreen),
                  title: Text(
                    'PDF Report',
                    style: ResponsiveText.body(context),
                  ),
                  subtitle: Text('Detailed energy usage report'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('PDF export started...'),
                        backgroundColor: AppColor.accentGreen,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Iconsax.document_text,
                    color: AppColor.accentGreen,
                  ),
                  title: Text('CSV Data', style: ResponsiveText.body(context)),
                  subtitle: Text('Raw data for spreadsheet analysis'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('CSV export started...'),
                        backgroundColor: AppColor.accentGreen,
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  void _showDeviceManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Manage Devices', style: ResponsiveText.stat(context)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Connected IoT Devices:',
                  style: ResponsiveText.body(context),
                ),
                SizedBox(height: Insets.md),
                ListTile(
                  leading: Icon(Iconsax.devices, color: AppColor.accentGreen),
                  title: Text(
                    'Smart Plug #1',
                    style: ResponsiveText.body(context),
                  ),
                  subtitle: Text('Living Room - Connected'),
                  trailing: Switch(value: true, onChanged: (value) {}),
                ),
                ListTile(
                  leading: Icon(Iconsax.devices, color: AppColor.accentGreen),
                  title: Text(
                    'Energy Monitor',
                    style: ResponsiveText.body(context),
                  ),
                  subtitle: Text('Main Panel - Connected'),
                  trailing: Switch(value: true, onChanged: (value) {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Add new device feature coming soon!'),
                      backgroundColor: AppColor.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: Text('Add Device', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Theme Mode', style: ResponsiveText.stat(context)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(
                    'Light Mode',
                    style: ResponsiveText.body(context),
                  ),
                  value: 'light',
                  groupValue: _themeMode,
                  onChanged: (value) => setState(() => _themeMode = value!),
                ),
                RadioListTile<String>(
                  title: Text('Dark Mode', style: ResponsiveText.body(context)),
                  value: 'dark',
                  groupValue: _themeMode,
                  onChanged: (value) => setState(() => _themeMode = value!),
                ),
                RadioListTile<String>(
                  title: Text(
                    'System Default',
                    style: ResponsiveText.body(context),
                  ),
                  value: 'system',
                  groupValue: _themeMode,
                  onChanged: (value) => setState(() => _themeMode = value!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Theme updated to ${_getThemeModeText(_themeMode)}',
                      ),
                      backgroundColor: AppColor.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: Text('Apply', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'About EnergySmart',
              style: ResponsiveText.stat(context),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version: 1.0.0', style: ResponsiveText.body(context)),
                SizedBox(height: Insets.sm),
                Text(
                  'Developer: EnergySmart Team',
                  style: ResponsiveText.body(context),
                ),
                SizedBox(height: Insets.sm),
                Text(
                  '© 2024 EnergySmart. All rights reserved.',
                  style: ResponsiveText.caption(context),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  void _navigateToSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Help & Support feature coming soon!'),
        backgroundColor: AppColor.accentGreen,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Logout', style: ResponsiveText.stat(context)),
            content: Text(
              'Are you sure you want to logout?',
              style: ResponsiveText.body(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Implement actual logout logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout successful!'),
                      backgroundColor: AppColor.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentRed,
                  foregroundColor: Colors.white,
                ),
                child: Text('Logout', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }
}
