import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';

class ContactAdminPage extends StatefulWidget {
  const ContactAdminPage({super.key});

  @override
  State<ContactAdminPage> createState() => _ContactAdminPageState();
}

class _ContactAdminPageState extends State<ContactAdminPage> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSupportRequest() async {
    if (_subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppColor.accentRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Simulate API call
      await Future.delayed(Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Support request submitted successfully!'),
            backgroundColor: AppColor.accentGreen,
          ),
        );

        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Contact Support', style: ResponsiveText.stat(context)),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Iconsax.message, color: AppColor.accentGreen, size: 28),
                SizedBox(width: Insets.sm),
                Text('Get Help & Support', style: ResponsiveText.stat(context)),
              ],
            ),
            SizedBox(height: Insets.sm),
            Text(
              'Contact our support team for assistance with your energy management needs.',
              style: ResponsiveText.body(context),
            ),
            SizedBox(height: Insets.lg),

            // Contact Information
            _buildContactInfoSection(context),
            SizedBox(height: Insets.lg),

            // Support Request Form
            _buildSupportFormSection(context),
            SizedBox(height: Insets.lg),

            // Quick Actions
            _buildQuickActionsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection(BuildContext context) {
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
              Icon(Iconsax.direct, color: AppColor.accentGreen, size: 24),
              SizedBox(width: Insets.sm),
              Text('Contact Information', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),

          _buildContactItem(
            context,
            Iconsax.direct,
            'Email Support',
            'support@energysmart.com',
            'Get help via email',
            () => _launchEmail(),
          ),
          SizedBox(height: Insets.md),

          _buildContactItem(
            context,
            Iconsax.call,
            'Phone Support',
            '+63 912 345 6789',
            'Call us directly',
            () => _launchPhone(),
          ),
          SizedBox(height: Insets.md),

          _buildContactItem(
            context,
            Iconsax.clock,
            'Office Hours',
            'Mon-Fri, 9:00 AM - 6:00 PM',
            'Available support hours',
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    IconData icon,
    String title,
    String value,
    String description,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: AppColor.accentGreen.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border:
              onTap != null ? Border.all(color: AppColor.accentGreen) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColor.accentGreen, size: 20),
            SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ResponsiveText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: Insets.xm),
                  Text(
                    value,
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.accentGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: Insets.xm),
                  Text(description, style: ResponsiveText.caption(context)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Iconsax.arrow_right_3,
                color: AppColor.accentGreen,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportFormSection(BuildContext context) {
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
              Icon(Iconsax.message_text, color: AppColor.primary, size: 24),
              SizedBox(width: Insets.sm),
              Text('Send Support Request', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Describe your issue and we\'ll get back to you as soon as possible.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          // Subject Field
          Text('Subject', style: ResponsiveText.label(context)),
          SizedBox(height: Insets.sm),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              hintText: 'Brief description of your issue',
              prefixIcon: Icon(Iconsax.tag, color: AppColor.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.primary, width: 2),
              ),
            ),
          ),
          SizedBox(height: Insets.md),

          // Message Field
          Text('Message', style: ResponsiveText.label(context)),
          SizedBox(height: Insets.sm),
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Please provide detailed information about your issue...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 100),
                child: Icon(Iconsax.message_text, color: AppColor.primary),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.disabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColor.primary, width: 2),
              ),
            ),
          ),
          SizedBox(height: Insets.lg),

          // Submit Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColor.primary, AppColor.accentGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSupportRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: Insets.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isSubmitting
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
                            'Submitting...',
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
                          Icon(Iconsax.send, color: Colors.white, size: 20),
                          SizedBox(width: Insets.sm),
                          Text(
                            'Submit Request',
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

  Widget _buildQuickActionsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColor.lowConsumption, width: 4),
          right: BorderSide(color: AppColor.lowConsumption, width: 4),
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
              Icon(Iconsax.flash_1, color: AppColor.lowConsumption, size: 24),
              SizedBox(width: Insets.sm),
              Text('Quick Actions', style: ResponsiveText.stat(context)),
            ],
          ),
          SizedBox(height: Insets.md),
          Text(
            'Common support actions and resources.',
            style: ResponsiveText.body(context),
          ),
          SizedBox(height: Insets.lg),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  'FAQ',
                  Iconsax.message_question,
                  () => _showFAQ(),
                ),
              ),
              SizedBox(width: Insets.md),
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  'Live Chat',
                  Iconsax.message,
                  () => _startLiveChat(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: AppColor.lowConsumption.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColor.lowConsumption),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColor.lowConsumption, size: 32),
            SizedBox(height: Insets.sm),
            Text(
              title,
              style: ResponsiveText.body(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColor.lowConsumption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchEmail() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening email client...'),
        backgroundColor: AppColor.accentGreen,
      ),
    );
  }

  void _launchPhone() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening phone dialer...'),
        backgroundColor: AppColor.accentGreen,
      ),
    );
  }

  void _showFAQ() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('FAQ feature coming soon!'),
        backgroundColor: AppColor.accentGreen,
      ),
    );
  }

  void _startLiveChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Live chat feature coming soon!'),
        backgroundColor: AppColor.accentGreen,
      ),
    );
  }
}
