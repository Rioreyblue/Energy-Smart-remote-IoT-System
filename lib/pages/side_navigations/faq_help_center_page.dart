import 'package:flutter/material.dart';
import '../../constants/constant.dart';
import 'package:iconsax/iconsax.dart';

class FAQHelpCenterPage extends StatelessWidget {
  const FAQHelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I reset my password?',
        'a': 'Go to settings > account > reset password.',
      },
      {
        'q': 'How to contact support?',
        'a': 'Use the Contact Admin page or email support@energysmart.com.',
      },
      {
        'q': 'How to export my bill?',
        'a': 'Go to Export Usage Data and select your preferred format.',
      },
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ / Help Center'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: ListView.separated(
                itemCount: faqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
                itemBuilder: (context, i) {
                  final faq = faqs[i];
                  return ExpansionTile(
                    leading: Icon(
                      Iconsax.info_circle,
                      color: AppColor.accentGreen,
                    ),
                    title: Text(
                      faq['q']!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: Insets.lg,
                          right: Insets.lg,
                          bottom: Insets.md,
                        ),
                        child: Text(
                          faq['a']!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
