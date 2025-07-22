import 'package:flutter/material.dart';
import '../../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import '../../widgets/card.dart';

class DataManagementPage extends StatelessWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage your app data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            AppCard(
              child: Row(
                children: [
                  Icon(Iconsax.trash, color: AppColor.accentRed, size: 28),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clear App Cache',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Remove all cached data and reset app state.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.accentRed,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Iconsax.trash),
                    label: const Text('Clear'),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Confirm Deletion'),
                              content: const Text(
                                'Are you sure you want to clear all app cache? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColor.accentRed,
                                  ),
                                  child: const Text('Delete'),
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                ),
                              ],
                            ),
                      );
                      if (confirmed == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Cache cleared!'),
                            backgroundColor: AppColor.accentGreen,
                          ),
                        );
                      }
                    },
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
