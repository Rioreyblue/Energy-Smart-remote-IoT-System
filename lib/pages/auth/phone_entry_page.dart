import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/auth_service.dart';
import 'package:exercise_app/services/phone_auth_service.dart';
import 'package:exercise_app/utils/app_logger.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final _phoneController = TextEditingController(text: '+63');
  final _authService = AuthService();

  bool _isSending = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prefillPhoneNumber();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _prefillPhoneNumber() async {
    if (!mounted) return;
    final phoneAuth = context.read<PhoneAuthService>();
    final existing = phoneAuth.phoneNumber;
    if (existing != null && existing.isNotEmpty) {
      _phoneController.text = existing;
      return;
    }

    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final profile = await _authService.getCurrentUserData();
      final mobile = profile?.mobileNumber.trim() ?? '';
      if (mounted && mobile.isNotEmpty) {
        _phoneController.text = mobile;
      }
    } catch (e) {
      AppLogger.w('[PhoneEntryPage] Unable to prefill phone: $e');
    }
  }

  Future<void> _sendOtp() async {
    final phoneAuth = context.read<PhoneAuthService>();
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      AppSnackbar.showError(
        context,
        'Enter the phone number to receive the OTP.',
      );
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    final success = await phoneAuth.verifyPhoneNumber(phoneNumber);

    if (!mounted) return;

    setState(() {
      _isSending = false;
      _statusMessage =
          success
              ? 'OTP sent. Enter the code once you receive it.'
              : phoneAuth.error;
    });

    if (success) {
      AppSnackbar.showSuccess(
        context,
        'Verification code sent to $phoneNumber.',
      );
      context.go('/');
    } else if (phoneAuth.error != null) {
      AppSnackbar.showError(context, phoneAuth.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_1, color: AppColor.accentGreen),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'Verify Your Number',
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
              _buildInfoCard(context),
              SizedBox(height: Insets.xl),
              _buildPhoneField(context),
              SizedBox(height: Insets.xl),
              _buildSendButton(context),
              SizedBox(height: Insets.md),
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(
                  'Already have a code? Enter it',
                  style: ResponsiveText.body(context).copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_statusMessage != null) ...[
                SizedBox(height: Insets.lg),
                _buildStatusBanner(
                  context,
                  _statusMessage!,
                  AppColor.accentGreen,
                  AppColor.accentGreen.withAlpha(26),
                ),
              ],
              Consumer<PhoneAuthService>(
                builder: (context, phoneAuth, _) {
                  if (phoneAuth.error == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: Insets.md),
                    child: _buildStatusBanner(
                      context,
                      phoneAuth.error!,
                      AppColor.accentRed,
                      AppColor.accentRed.withAlpha(26),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColor.accentGreen.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send a one-time password to your phone.',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.primary, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: Insets.sm),
          Text(
            'SmsChef delivers the code through your registered device. '
            'Keep the SmsChef app online and the device connected so that the SMS can be sent.',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile number',
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+63 9XX XXX XXXX',
            prefixIcon: const Icon(Iconsax.mobile),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (_) => context.read<PhoneAuthService>().clearError(),
        ),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSending ? null : _sendOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.accentGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child:
            _isSending
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Text(
                  'Send verification code',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
      ),
    );
  }

  Widget _buildStatusBanner(
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
}
