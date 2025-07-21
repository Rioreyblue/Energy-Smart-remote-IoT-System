import 'package:flutter/material.dart';
import '../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import '../widgets/card.dart';

class TipsAdvicePage extends StatelessWidget {
  const TipsAdvicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>>tips = [
      {
        'title': 'Unplug Devices',
        'desc': 'Unplug electronics when not in use to save energy.',
        'icon': Iconsax.electricity,
      },
      {
        'title': 'Use LED Bulbs',
        'desc': 'Switch to LED bulbs for lower consumption.',
        'icon': Iconsax.lamp_on,
      },
      {
        'title': 'Set AC to 24°C',
        'desc': 'Optimal AC temperature for savings.',
        'icon': Iconsax.element_3,
      },
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tips & Advice'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Energy Saving Tips',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: ListView.separated(
                itemCount: tips.length,
                separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
                itemBuilder: (context, i) {
                  final tip = tips[i];
                  return AppCard(
                    child: Row(
                      children: [
                        Icon(
                          tip['icon'] as IconData,
                          color: AppColor.accentGreen,
                          size: 28,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title']!,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                tip['desc']!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
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
