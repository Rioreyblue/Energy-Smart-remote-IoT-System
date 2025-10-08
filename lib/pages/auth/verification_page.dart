import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:go_router/go_router.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';
import 'package:exercise_app/utils/validation_utils.dart';

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
  final _otpController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isResending = false;
  int _remainingTime = 0;
  int _verificationAttempts = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
    _loadUserData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final userData = await _authService.getCurrentUserData();
      if (userData != null) {
        setState(() {
          _verificationAttempts = userData.verificationAttempts;
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final otp = _otpController.text.trim();

    // Check if verification attempts exceeded
    if (_verificationAttempts >= 3) {
      AppSnackbar.showError(
        context,
        'Too many verification attempts. Please try again later.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Only handle phone verification here
      final isVerified = await _authService.verifyPhoneWithOTP(otp);

      if (isVerified) {
        // Update verification attempts
        final user = _authService.currentUser;
        if (user != null) {
          await _authService.updateVerificationAttempts(user.uid);
        }

        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Phone verification successful! Welcome to Energy Smart.',
          );

          // Navigate to home page using GoRouter
          context.go('/home');
        }
      } else {
        // Update verification attempts
        final user = _authService.currentUser;
        if (user != null) {
          await _authService.updateVerificationAttempts(user.uid);
          setState(() {
            _verificationAttempts++;
          });
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
    if (_remainingTime > 0) return;

    setState(() => _isResending = true);

    try {
      await _authService.resendVerificationCode(
        phoneNumber: widget.mobileNumber,
        verificationType: widget.verificationType,
      );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Verification code sent successfully!',
        );

        setState(() {
          _remainingTime = 30;
        });
        _startCooldownTimer();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
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
              _buildVerificationForm(context, isDark),

              SizedBox(height: Insets.xl),

              // Resend Button
              _buildResendButton(context),
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

  Widget _buildVerificationForm(BuildContext context, bool isDark) {
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
            // OTP Input (only for phone verification)
            if (widget.verificationType == 'phone') ...[
              _buildOTPInput(context),
              SizedBox(height: Insets.lg),
              // Verify Button (only for phone verification)
              _buildVerifyButton(context),
            ],

            // Check Email Button (for email verification)
            if (widget.verificationType == 'email')
              _buildCheckEmailButton(context),

            SizedBox(height: Insets.md),

            // Attempts Counter
            if (_verificationAttempts > 0)
              Text(
                'Attempts: $_verificationAttempts/3',
                style: ResponsiveText.caption(context).copyWith(
                  color:
                      _verificationAttempts >= 3
                          ? Colors.red
                          : AppColor.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPInput(BuildContext context) {
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
          controller: _otpController,
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
            _verifyOTP();
          },
          onChanged: (value) {},
          validator: (value) {
            return ValidationUtils.validateOTP(value ?? '');
          },
        ),
      ],
    );
  }

  Widget _buildVerifyButton(BuildContext context) {
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
        onPressed: _isLoading ? null : _verifyOTP,
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
          context.go('/home');
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

  Widget _buildResendButton(BuildContext context) {
    return Column(
      children: [
        Text(
          'Didn\'t receive the code?',
          style: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.textSecondary),
        ),
        SizedBox(height: Insets.sm),
        TextButton(
          onPressed: _remainingTime > 0 || _isResending ? null : _resendCode,
          child:
              _isResending
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColor.accentGreen,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    _remainingTime > 0
                        ? 'Resend in ${_remainingTime}s'
                        : 'Resend Code',
                    style: ResponsiveText.body(context).copyWith(
                      color:
                          _remainingTime > 0
                              ? AppColor.textSecondary
                              : AppColor.accentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ],
    );
  }
}
