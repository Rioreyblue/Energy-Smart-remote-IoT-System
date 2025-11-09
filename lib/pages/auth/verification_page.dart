import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:go_router/go_router.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/services/phone_auth_service.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';
import 'package:exercise_app/utils/validation_utils.dart';
import 'package:exercise_app/utils/app_logger.dart';
import 'package:provider/provider.dart';

class VerificationPage extends StatefulWidget {
  final String verificationType; // 'email' or 'phone'
  final String contactInfo; // email or phone number
  final String firstName;
  final String lastName;
  final String middleName;
  final String mobileNumber;
  final String email;
  final String energyProvider;
  final String address;

  const VerificationPage({
    super.key,
    required this.verificationType,
    required this.contactInfo,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.mobileNumber,
    required this.email,
    required this.energyProvider,
    required this.address,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  int _verificationAttempts = 0;
  String? _statusMessage;
  String _otpValue = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final userData = await _authService.getCurrentUserData();
      if (userData != null) {
        setState(() {
          _verificationAttempts = userData.verificationAttempts;
        });
        AppLogger.d(
          '[VerificationPage] Loaded verification attempts: $_verificationAttempts',
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    // Check if widget is still mounted before proceeding
    if (!mounted) return;

    if (!_formKey.currentState!.validate()) return;

    final otp = _otpValue.trim();
    final phoneAuthService = context.read<PhoneAuthService>();

    if (widget.verificationType == 'phone' && !phoneAuthService.isCodeSent) {
      AppSnackbar.showError(
        context,
        'Send the verification code first before entering the OTP.',
      );
      return;
    }

    // Check if verification attempts exceeded (limit set to 7)
    final attemptsExceeded = ValidationUtils.isVerificationAttemptsExceeded(
      _verificationAttempts,
    );
    if (attemptsExceeded) {
      AppSnackbar.showError(
        context,
        'Too many verification attempts. Please wait 2 minutes before trying again.',
      );
      AppLogger.w(
        '[VerificationPage] Verification attempts exceeded: $_verificationAttempts',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isVerified = await _authService.verifyPhoneWithOTP(otp);
      phoneAuthService.clearError();

      if (isVerified) {
        // Update verification attempts
        final user = _authService.currentUser;
        if (user != null) {
          await _authService.updateVerificationAttempts(user.uid);
          AppLogger.i('[VerificationPage] Verification successful');
        }

        if (mounted) {
          phoneAuthService.reset();
          setState(() {
            _statusMessage = null;
          });
          AppSnackbar.showSuccess(
            context,
            'Phone verification successful! Welcome to Energy Smart.',
          );

          // Refresh auth state by reloading user data
          await _authService.getCurrentUserData();

          // Small delay to ensure auth state propagates
          await Future.delayed(const Duration(milliseconds: 300));

          // Navigate to home once verification completes
          if (mounted) {
            context.go('/home');
          }
        }
      } else {
        // Update verification attempts
        final user = _authService.currentUser;
        if (user != null) {
          await _authService.updateVerificationAttempts(user.uid);
          // Reload user data to get the updated attempts count
          await _loadUserData();
        }

        if (mounted) {
          AppSnackbar.showError(
            context,
            'Invalid verification code. Please try again.',
          );
        }
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

  Future<void> _resendCode() async {
    final phoneAuth = context.read<PhoneAuthService>();
    if (!mounted || !phoneAuth.canResend) return;

    setState(() {
      _statusMessage = null;
    });

    final success = await phoneAuth.resendCode();

    if (!mounted) return;

    setState(() {
      _statusMessage =
          success
              ? 'OTP resent. Use the latest code delivered to your phone.'
              : phoneAuth.error;
    });

    if (success) {
      AppSnackbar.showSuccess(context, 'Verification code re-sent.');
    } else if (phoneAuth.error != null) {
      AppSnackbar.showError(context, phoneAuth.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final phoneAuth = context.watch<PhoneAuthService>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_1, color: AppColor.accentGreen),
          onPressed: () => context.go('login'),
        ),
        title: Text(
          'Verify ${widget.verificationType == 'email' ? 'Email' : 'Phone'}',
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

              SizedBox(height: Insets.xl),

              // Verification Form
              _buildVerificationForm(context, isDark, phoneAuth),
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
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColor.accentGreen, AppColor.lowConsumption],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: AppColor.accentGreen.withAlpha(64),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            widget.verificationType == 'email' ? Iconsax.sms : Iconsax.mobile,
            color: Colors.white,
            size: 50,
          ),
        ),

        SizedBox(height: Insets.lg),

        // Title
        Text(
          'Verify Your ${widget.verificationType == 'email' ? 'Email' : 'Phone'}',
          style: ResponsiveText.headline(
            context,
          ).copyWith(color: AppColor.primary, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: Insets.sm),

        // Subtitle
        Text(
          widget.verificationType == 'email'
              ? 'We sent a verification email to\n${widget.contactInfo}\n\nPlease check your inbox and click the verification link, then tap "Check Email Verification" below.'
              : 'We sent a verification code to\n${widget.contactInfo}\n\nPlease enter the 6-digit code you received via SMS.',
          style: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVerificationForm(
    BuildContext context,
    bool isDark,
    PhoneAuthService phoneAuth,
  ) {
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
            if (widget.verificationType == 'phone') ...[
              _buildPhoneVerificationSection(context, phoneAuth),
            ] else ...[
              _buildCheckEmailButton(context),
              SizedBox(height: Insets.md),
              _buildResendEmailButton(context),
            ],

            if (_verificationAttempts > 0) ...[
              SizedBox(height: Insets.md),
              Text(
                'Attempts: $_verificationAttempts/5',
                style: ResponsiveText.caption(context).copyWith(
                  color:
                      _verificationAttempts >= 5
                          ? Colors.red
                          : AppColor.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneVerificationSection(
    BuildContext context,
    PhoneAuthService phoneAuth,
  ) {
    final canResend = phoneAuth.canResend;
    final hasSentCode = phoneAuth.isCodeSent;
    final resendLabel =
        hasSentCode && !canResend
            ? 'Resend in ${phoneAuth.formattedTime}'
            : 'Resend code';
    final phoneDisplay = _fallbackPhoneDisplay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: AppColor.accentGreen.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconsax.info_circle, color: AppColor.accentGreen),
              SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'SmsChef sends the OTP using your registered device. '
                  'Make sure it stays online so the code can arrive.',
                  style: ResponsiveText.body(context).copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Insets.lg),
        Text(
          'Code sent to',
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.primary.withAlpha(90)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Iconsax.mobile, color: AppColor.primary),
              SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  phoneAuth.phoneNumber?.isNotEmpty == true
                      ? phoneAuth.phoneNumber!
                      : (phoneDisplay ?? 'No number on file'),
                  style: ResponsiveText.body(context).copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Insets.md),
        _buildOTPInput(context, phoneAuth),
        SizedBox(height: Insets.lg),
        _buildVerifyButton(context, phoneAuth),
        SizedBox(height: Insets.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => context.go('/sms'),
              child: Text(
                'Use a different number',
                style: ResponsiveText.body(context).copyWith(
                  color: AppColor.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: hasSentCode && canResend ? _resendCode : null,
              child: Text(
                resendLabel,
                style: ResponsiveText.body(context).copyWith(
                  color:
                      hasSentCode && canResend
                          ? AppColor.accentGreen
                          : AppColor.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (_statusMessage != null) ...[
          SizedBox(height: Insets.lg),
          _buildBanner(
            context,
            _statusMessage!,
            AppColor.accentGreen,
            AppColor.accentGreen.withAlpha(26),
          ),
        ],
        if (phoneAuth.error != null) ...[
          SizedBox(height: Insets.md),
          _buildBanner(
            context,
            phoneAuth.error!,
            AppColor.accentRed,
            AppColor.accentRed.withAlpha(26),
          ),
        ],
      ],
    );
  }

  Widget _buildOTPInput(BuildContext context, PhoneAuthService phoneAuth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Verification Code',
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        PinCodeTextField(
          appContext: context,
          length: 6,
          enabled: !_isLoading,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(12),
            fieldHeight: 56,
            fieldWidth: 48,
            activeFillColor: Theme.of(context).colorScheme.surface,
            inactiveFillColor: Theme.of(context).colorScheme.surface,
            selectedFillColor: Theme.of(context).colorScheme.surface,
            activeColor: AppColor.accentGreen,
            inactiveColor: AppColor.disabled,
            selectedColor: AppColor.accentGreen,
          ),
          enableActiveFill: true,
          onCompleted: (value) {
            setState(() => _otpValue = value);
            // Check if mounted before calling _verifyOTP
            if (mounted && phoneAuth.isCodeSent) {
              _verifyOTP();
            }
          },
          onChanged: (value) => _otpValue = value,
          validator: (value) {
            return ValidationUtils.validateOTP(value ?? '');
          },
        ),
        if (!phoneAuth.isCodeSent)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Send a code from the previous step, then enter the 6-digit OTP here.',
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: AppColor.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildVerifyButton(BuildContext context, PhoneAuthService phoneAuth) {
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
        onPressed:
            _isLoading || !phoneAuth.isCodeSent ? null : () => _verifyOTP(),
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
                    Icon(Iconsax.verify, color: Colors.white),
                    SizedBox(width: Insets.sm),
                    Text(
                      'Verify Code',
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

  Widget _buildCheckEmailButton(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.accentGreen),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _checkEmailVerification,
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColor.accentGreen,
                    strokeWidth: 2,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.refresh,
                      color: AppColor.accentGreen,
                      size: 20,
                    ),
                    SizedBox(width: Insets.sm),
                    Text(
                      'Check Email Verification',
                      style: ResponsiveText.body(context).copyWith(
                        color: AppColor.accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildResendEmailButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _isLoading ? null : _resendEmailVerification,
        child: Text(
          'Resend verification email',
          style: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.accentGreen, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    String message,
    Color foreground,
    Color background,
  ) {
    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, color: foreground, size: 20),
          SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkEmailVerification() async {
    setState(() => _isLoading = true);

    try {
      final isVerified = await _authService.verifyEmail();

      if (isVerified) {
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Email verified successfully! Welcome to Energy Smart.',
          );

          // Refresh auth state by reloading user data
          await _authService.getCurrentUserData();

          // Small delay to ensure auth state propagates
          await Future.delayed(const Duration(milliseconds: 300));

          // Navigate to root - AuthWrapper will redirect to /home if fully verified
          if (mounted) {
            context.go('/');
          }
        }
      } else {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Email not yet verified. Please check your inbox and click the verification link, then try again.',
          );
        }
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

  String? _fallbackPhoneDisplay() {
    final trimmedMobile = widget.mobileNumber.trim();
    if (trimmedMobile.isNotEmpty) {
      return trimmedMobile;
    }

    final contact = widget.contactInfo.trim();
    if (contact.isNotEmpty && RegExp(r'^\+?[\d ]+$').hasMatch(contact)) {
      return contact;
    }

    return null;
  }

  Future<void> _resendEmailVerification() async {
    setState(() => _isLoading = true);

    try {
      await _authService.resendVerificationCode(verificationType: 'email');
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Verification email sent. Please check your inbox.',
        );
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
}
