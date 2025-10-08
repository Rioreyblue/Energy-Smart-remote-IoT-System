import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';
import 'verification_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedEnergyProvider = 'MOELCI Uno';
  String _selectedAuthMethod = 'email'; // 'email' or 'phone'

  final List<String> _energyProviders = ['MOELCI Uno'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _mobileNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_selectedAuthMethod == 'email') {
        await _registerWithEmail();
      } else {
        await _registerWithPhone();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerWithEmail() async {
    final user = await _authService.registerUserWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      mobileNumber: _mobileNumberController.text.trim(),
      energyProvider: _selectedEnergyProvider,
      address: _addressController.text.trim(),
    );

    if (user != null) {
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Registration successful! Please check your email for verification.',
        );

        // Navigate to verification page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => VerificationPage(
                  verificationType: 'email',
                  contactInfo: _emailController.text.trim(),
                  firstName: _firstNameController.text.trim(),
                  lastName: _lastNameController.text.trim(),
                  middleName: _middleNameController.text.trim(),
                  mobileNumber: _mobileNumberController.text.trim(),
                  email: _emailController.text.trim(),
                  energyProvider: _selectedEnergyProvider,
                  address: _addressController.text.trim(),
                ),
          ),
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Registration failed. Please try again.',
        );
      }
    }
  }

  Future<void> _registerWithPhone() async {
    final verificationId = await _authService.registerUserWithPhone(
      phoneNumber: _mobileNumberController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      email: _emailController.text.trim(),
      energyProvider: _selectedEnergyProvider,
      address: _addressController.text.trim(),
    );

    if (verificationId != null) {
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'OTP sent to your phone number. Please verify to complete registration.',
        );

        // Navigate to verification page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => VerificationPage(
                  verificationType: 'phone',
                  contactInfo: _mobileNumberController.text.trim(),
                  firstName: _firstNameController.text.trim(),
                  lastName: _lastNameController.text.trim(),
                  middleName: _middleNameController.text.trim(),
                  mobileNumber: _mobileNumberController.text.trim(),
                  email: _emailController.text.trim(),
                  energyProvider: _selectedEnergyProvider,
                  address: _addressController.text.trim(),
                ),
          ),
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Registration failed. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_1, color: AppColor.accentGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Account',
          style: ResponsiveText.title(
            context,
          ).copyWith(color: AppColor.primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context),

              SizedBox(height: Insets.lg),

              // Registration Form
              _buildRegistrationForm(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Icon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Container(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/icon/update_icon.png',
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            //dsfsdfds
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColor.accentGreen, AppColor.lowConsumption],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColor.accentGreen.withAlpha(64),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(Iconsax.user_add, color: Colors.white, size: 40),
            ),
          ],
        ),

        SizedBox(height: Insets.lg),

        // Title
        Text(
          'Join Energy Smart',
          style: ResponsiveText.headline(
            context,
          ).copyWith(color: AppColor.primary, fontWeight: FontWeight.bold),
        ),

        SizedBox(height: Insets.sm),

        // Subtitle
        Text(
          'Create your account to start managing energy consumption',
          style: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegistrationForm(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name Fields
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Iconsax.user,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'First name is required';
                      }
                      if (value.length < 2) {
                        return 'First name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: Insets.md),
                Expanded(
                  child: _buildTextField(
                    context,
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Iconsax.user,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Last name is required';
                      }
                      if (value.length < 2) {
                        return 'Last name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: Insets.lg),

            // Middle Name
            _buildTextField(
              context,
              controller: _middleNameController,
              label: 'Middle Name (Optional)',
              icon: Iconsax.user,
            ),

            SizedBox(height: Insets.lg),

            // Mobile Number
            _buildTextField(
              context,
              controller: _mobileNumberController,
              label: 'Mobile Number',
              icon: Iconsax.mobile,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Mobile number is required';
                }
                if (!RegExp(r'^09\d{9}$').hasMatch(value)) {
                  return 'Please enter a valid mobile number (09XXXXXXXXX)';
                }
                return null;
              },
            ),

            SizedBox(height: Insets.lg),

            // Email
            _buildTextField(
              context,
              controller: _emailController,
              label: 'Email Address',
              icon: Iconsax.sms,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            SizedBox(height: Insets.lg),

            // Energy Provider Dropdown
            _buildEnergyProviderDropdown(context),

            SizedBox(height: Insets.lg),

            // Address
            _buildTextField(
              context,
              controller: _addressController,
              label: 'Address',
              icon: Iconsax.location,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Address is required';
                }
                if (value.length < 5) {
                  return 'Address must be at least 5 characters';
                }
                return null;
              },
            ),

            SizedBox(height: Insets.lg),

            // Authentication Method Selector
            _buildAuthMethodSelector(context),

            SizedBox(height: Insets.lg),

            // Password (only for email registration)
            if (_selectedAuthMethod == 'email') ...[
              _buildPasswordField(
                context,
                controller: _passwordController,
                label: 'Password',
                obscureText: _obscurePassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'Password must contain at least one uppercase letter';
                  }
                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                    return 'Password must contain at least one lowercase letter';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Password must contain at least one number';
                  }
                  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                    return 'Password must contain at least one special character';
                  }
                  return null;
                },
              ),

              SizedBox(height: Insets.lg),

              // Confirm Password
              _buildPasswordField(
                context,
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              SizedBox(height: Insets.lg),
            ],

            SizedBox(height: Insets.xl),

            // Register Button
            _buildRegisterButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            prefixIcon: Icon(icon, color: AppColor.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.accentGreen, width: 2),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            prefixIcon: Icon(Iconsax.lock, color: AppColor.primary),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Iconsax.eye : Iconsax.eye_slash,
                color: AppColor.primary,
              ),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.accentGreen, width: 2),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildEnergyProviderDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Energy Provider',
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.disabled),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedEnergyProvider,
            decoration: InputDecoration(
              prefixIcon: Icon(Iconsax.flash_1, color: AppColor.primary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.sm,
              ),
            ),
            items:
                _energyProviders.map((String provider) {
                  return DropdownMenuItem<String>(
                    value: provider,
                    child: Text(provider),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedEnergyProvider = newValue!;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthMethodSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration Method',
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        Row(
          children: [
            Expanded(
              child: _buildAuthMethodOption(
                context,
                title: 'Email',
                subtitle: 'Password + Email',
                icon: Iconsax.sms,
                value: 'email',
              ),
            ),
            SizedBox(width: Insets.md),
            Expanded(
              child: _buildAuthMethodOption(
                context,
                title: 'Phone',
                subtitle: 'SMS OTP',
                icon: Iconsax.mobile,
                value: 'phone',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthMethodOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedAuthMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAuthMethod = value;
        });
      },
      child: Container(
        padding: EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColor.accentGreen : AppColor.disabled,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected
                  ? AppColor.accentGreen.withAlpha(26)
                  : Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColor.accentGreen : AppColor.primary,
              size: 24,
            ),
            SizedBox(height: Insets.sm),
            Text(
              title,
              style: ResponsiveText.label(context).copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColor.accentGreen : AppColor.primary,
              ),
            ),
            Text(
              subtitle,
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColor.accentGreen, AppColor.lowConsumption],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColor.accentGreen.withAlpha(64),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isLoading
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.user_add, color: Colors.white),
                    SizedBox(width: Insets.sm),
                    Text(
                      'Create Account',
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
