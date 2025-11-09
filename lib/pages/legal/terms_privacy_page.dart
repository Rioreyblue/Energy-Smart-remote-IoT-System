import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';

class TermsPrivacyPage extends StatelessWidget {
  const TermsPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: AppColor.primary,
        elevation: 0,
      ),
      backgroundColor: theme.colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SectionTitle('EnergySmart Terms of Service and Privacy Summary'),
            _Para(
              'EnergySmart lets you monitor energy usage, control supported devices, view insights, and receive alerts for optimization and safety.',
            ),
            _SectionTitle('Account and Eligibility'),
            _Bullets([
              'Provide accurate information and keep your account secure.',
              'You must be of legal age or have guardian consent.',
            ]),
            _SectionTitle('Device Control and Safety'),
            _Bullets([
              'You are responsible for safe use of connected devices.',
              'Do not use for unsafe automation or beyond device ratings.',
              'We are not liable for damage due to misuse, wiring or faults.',
            ]),
            _SectionTitle('Acceptable Use'),
            _Bullets([
              'No reverse engineering, scraping or bypassing security.',
              'No unauthorized access to other users’ data or devices.',
              'No harmful, abusive or infringing content.',
            ]),
            _SectionTitle('Availability and Updates'),
            _Bullets([
              'Features may change; maintenance may cause downtime.',
              'Updates may be required for certain features.',
            ]),
            _SectionTitle('Third‑Party Services'),
            _Para(
              'We use Firebase (Auth, Firestore/Realtime DB, Messaging, App Check) and analytics/logging providers. Third‑party terms and privacy policies apply.',
            ),
            _SectionTitle('Data We Collect'),
            _Bullets([
              'Account: name, email, mobile number, address, energy provider.',
              'Device: consumption (kWh), power (W), status (on/off), voltage/current (if supported).',
              'Usage logs: scenes, schedules, alerts, notifications you enable.',
              'Diagnostics: crash/performance, device model/OS, in‑app events.',
            ]),
            _SectionTitle('How We Use Data'),
            _Bullets([
              'Provide and secure your account.',
              'Display usage, compute costs/insights, send notifications.',
              'Improve reliability, detect abuse (via App Check), support.',
              'Comply with legal requirements.',
            ]),
            _SectionTitle('Data Sharing'),
            _Bullets([
              'We do not sell personal data.',
              'We share with service providers (e.g., Firebase).',
              'We may disclose if required by law or to protect safety/rights.',
            ]),
            _SectionTitle('Security'),
            _Para(
              'We use App Check, auth safeguards, and transport encryption. No method is 100% secure; keep your credentials safe.',
            ),
            _SectionTitle('Your Choices'),
            _Bullets([
              'Manage notifications in‑app and at OS level.',
              'Request data correction or deletion (subject to limits).',
              'Disconnect devices at any time; historical data may persist as required.',
            ]),
            _SectionTitle('Data Retention'),
            _Para(
              'We retain data while you use the service and as needed for security, audit and legal purposes. On deletion, we remove or anonymize where allowed.',
            ),
            _SectionTitle('Children’s Privacy'),
            _Para(
              'Not directed to children under the applicable age of consent. Contact support if you believe a child has provided data.',
            ),
            _SectionTitle('Disclaimers and Liability'),
            _Para(
              'EnergySmart provides estimates and insights “as is”; bills may differ. We are not liable for losses from misuse, electrical faults or outages.',
            ),
            _SectionTitle('Termination'),
            _Para(
              'We may suspend or terminate for violations. You may request account deletion at any time.',
            ),
            _SectionTitle('Changes'),
            _Para(
              'We may update these terms and privacy summary. Material changes will be notified in‑app or via email. Continued use accepts changes.',
            ),
            _SectionTitle('Contact'),
            _Para(
              'Support: support@energysmart.example\nPrivacy: privacy@energysmart.example\nAddress: [Your company/legal entity address]',
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: ResponsiveText.title(
          context,
        ).copyWith(color: AppColor.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Para extends StatelessWidget {
  final String text;
  const _Para(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: ResponsiveText.body(
          context,
        ).copyWith(color: AppColor.textSecondary, height: 1.45),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets(this.items);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                        child: Text(
                          e,
                          style: ResponsiveText.body(context).copyWith(
                            color: AppColor.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}
