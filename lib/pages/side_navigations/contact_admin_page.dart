import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:go_router/go_router.dart';

class ContactAdminPage extends StatefulWidget {
  const ContactAdminPage({super.key});

  @override
  State<ContactAdminPage> createState() => _ContactAdminPageState();
}

class _ContactAdminPageState extends State<ContactAdminPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Contact Support', style: ResponsiveText.stat(context)),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_1),
          onPressed: () => context.go('/home'),
          color: Colors.white,
        ),
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
}
