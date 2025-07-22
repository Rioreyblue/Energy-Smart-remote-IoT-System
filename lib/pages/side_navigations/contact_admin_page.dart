import 'package:flutter/material.dart';
import '../../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import '../../widgets/card.dart';

class ContactAdminPage extends StatelessWidget {
  const ContactAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Admin / Helpdesk'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Support',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Iconsax.direct,
                        color: AppColor.accentGreen,
                        size: 28,
                      ),
                      const SizedBox(width: Insets.md),
                      Text(
                        'Email',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xm),
                  Text(
                    'support@energysmart.com',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Icon(Iconsax.call, color: AppColor.accentGreen, size: 28),
                      const SizedBox(width: Insets.md),
                      Text(
                        'Phone',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xm),
                  Text(
                    '+63 912 345 6789',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Icon(
                        Iconsax.clock,
                        color: AppColor.accentGreen,
                        size: 28,
                      ),
                      const SizedBox(width: Insets.md),
                      Text(
                        'Office Hours',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xm),
                  Text(
                    'Mon-Fri, 9:00 AM - 6:00 PM',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Insets.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Iconsax.message),
                      label: const Text('Chat Support'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
