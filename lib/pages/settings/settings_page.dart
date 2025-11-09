import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/components/header.dart';
import 'package:exercise_app/services/settings_service.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/services/notification_service.dart';
import 'package:exercise_app/utils/snackbar_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Services
  final SettingsService _settingsService = SettingsService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // User Profile State
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String _userAddress = '';

  // Controllers for profile editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Controllers for password change
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Settings State
  bool _pushNotifications = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Load existing settings
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Load settings
      await _settingsService.loadSettings();

      setState(() {
        _pushNotifications = _settingsService.getPushNotifications();
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load user profile from Firebase Auth and Firestore
  Future<void> _loadUserProfile() async {
    try {
      // Get email from Firebase Auth (works for both email/password and Google sign-in)
      final currentUser = _authService.currentUser;
      final email = currentUser?.email ?? '';

      // Get user data from AuthService (UserModel from Firestore)
      final userData = await _authService.getCurrentUserData();

      String name = '';
      String phone = '';
      String address = '';

      if (userData != null) {
        // Construct full name from UserModel
        final nameParts = <String>[];
        if (userData.firstName.isNotEmpty) nameParts.add(userData.firstName);
        if (userData.middleName.isNotEmpty) nameParts.add(userData.middleName);
        if (userData.lastName.isNotEmpty) nameParts.add(userData.lastName);
        name = nameParts.join(' ').trim();

        // Get phone from UserModel or Firebase Auth
        phone =
            userData.mobileNumber.isNotEmpty
                ? userData.mobileNumber
                : currentUser?.phoneNumber ?? '';

        // Get address from UserModel
        address = userData.address;
      } else {
        // Fallback to Firebase Auth if UserModel is not available
        name = currentUser?.displayName ?? '';
        phone = currentUser?.phoneNumber ?? '';
      }

      // Try to get additional profile data from SettingsService (Firestore subcollection)
      final profile = await _settingsService.getUserProfile();
      if (profile != null) {
        // Use profile data if available, otherwise use the values from above
        name = profile['name']?.toString().trim() ?? name;
        phone = profile['phone']?.toString().trim() ?? phone;
        address = profile['address']?.toString().trim() ?? address;
      }

      setState(() {
        _userName = name;
        _userEmail = email;
        _userPhone = phone;
        _userAddress = address;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      // Set email from Firebase Auth as fallback even if other data fails
      final currentUser = _authService.currentUser;
      if (currentUser?.email != null) {
        setState(() {
          _userEmail = currentUser!.email!;
        });
      }
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
                    Header(responsiveFontSize: _responsiveFontSize),
                    SizedBox(height: Insets.lg),

                    // Account Section
                    _buildSectionHeader(context, 'Account', Iconsax.user),
                    _buildAccountSection(context),
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
            'Test Notification',
            'Send a test push notification',
            Iconsax.notification_bing,
            () => _testNotification(context),
          ),
        ],
      ),
    );
  }

  // Test notification
  Future<void> _testNotification(BuildContext context) async {
    try {
      await _notificationService.sendTestNotification();
      if (mounted) {
        showSuccessSnackBar(context, 'Test notification sent!');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send test notification: $e');
      }
    }
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
        activeTrackColor: AppColor.accentGreen.withAlpha(180),
        activeThumbColor: AppColor.accentGreen,
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

  // Settings update methods
  Future<void> _updatePushNotifications(bool value) async {
    setState(() => _pushNotifications = value);
    await _settingsService.setPushNotifications(value);
  }

  // Dialog methods
  Future<void> _showEditProfileDialog(BuildContext context) async {
    // Reload profile data to ensure we have the latest information
    await _loadUserProfile();

    // Initialize controllers with current values after loading
    _nameController.text = _userName;
    _emailController.text = _userEmail;
    _phoneController.text = _userPhone;
    _addressController.text = _userAddress;

    if (!mounted) return;

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
                  _buildTextField('Name', _nameController),
                  SizedBox(height: Insets.md),
                  _buildReadOnlyTextField('Email', _emailController),
                  SizedBox(height: Insets.sm),
                  Text(
                    'Email cannot be changed. Contact support if you need to update your email.',
                    style: ResponsiveText.caption(context).copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(153),
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: Insets.md),
                  _buildTextField('Phone', _phoneController),
                  SizedBox(height: Insets.md),
                  _buildTextField('Address', _addressController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: ResponsiveText.body(context)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _saveProfile(context);
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

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildReadOnlyTextField(
    String label,
    TextEditingController controller,
  ) {
    return TextFormField(
      controller: controller,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(102),
          ),
        ),
      ),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
      ),
    );
  }

  // Save profile to Firestore (excluding email)
  Future<void> _saveProfile(BuildContext context) async {
    try {
      // Don't update email - it should remain from Firebase Auth
      // Only update name, phone, and address
      final profileData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Update profile in Firestore subcollection
      await _settingsService.updateUserProfile(profileData);

      // Update local state (keep email from Firebase Auth)
      setState(() {
        _userName = _nameController.text.trim();
        // Keep _userEmail from Firebase Auth, don't update it
        _userPhone = _phoneController.text.trim();
        _userAddress = _addressController.text.trim();
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColor.accentGreen,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    // Clear controllers
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Change Password', style: ResponsiveText.stat(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: Insets.md),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: Insets.md),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
                onPressed: () => _savePasswordChange(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: Text('Update', style: ResponsiveText.body(context)),
              ),
            ],
          ),
    );
  }

  Future<void> _savePasswordChange(BuildContext context) async {
    // Validation
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppColor.accentRed,
        ),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: AppColor.accentRed,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: AppColor.accentRed,
        ),
      );
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: AppColor.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: ${e.toString()}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
}
