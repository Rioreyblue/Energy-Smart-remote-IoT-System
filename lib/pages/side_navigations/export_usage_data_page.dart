import 'package:flutter/material.dart';
import '../../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import '../../widgets/card.dart';

class ExportUsageDataPage extends StatefulWidget {
  const ExportUsageDataPage({super.key});

  @override
  State<ExportUsageDataPage> createState() => _ExportUsageDataPageState();
}

class _ExportUsageDataPageState extends State<ExportUsageDataPage> {
  String _format = 'CSV';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Usage Data'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export your usage data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            AppCard(
              child: Row(
                children: [
                  Icon(Iconsax.export_1, color: AppColor.accentGreen, size: 28),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _format,
                      items: const [
                        DropdownMenuItem(value: 'CSV', child: Text('CSV')),
                        DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                      ],
                      onChanged: (val) => setState(() => _format = val!),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Exported as $_format!'),
                          backgroundColor: AppColor.accentGreen,
                        ),
                      );
                    },
                    child: const Text('Export'),
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
