import 'package:flutter/material.dart';
import '../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import '../widgets/card.dart';

class BillHistoryPage extends StatelessWidget {
  const BillHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bills = [
      {
        'duration': 'May 2024',
        'start': '2024-05-01',
        'end': '2024-05-31',
        'amount': '₱1,200',
      },
      {
        'duration': 'April 2024',
        'start': '2024-04-01',
        'end': '2024-04-30',
        'amount': '₱1,050',
      },
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill History'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Bill History',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: ListView.separated(
                itemCount: bills.length,
                separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
                itemBuilder: (context, i) {
                  final bill = bills[i];
                  return AppCard(
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.receipt,
                          color: AppColor.accentGreen,
                          size: 28,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bill['duration']!,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${bill['start']} - ${bill['end']}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          bill['amount']!,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColor.accentGreen),
                        ),
                      ],
                    ),
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
