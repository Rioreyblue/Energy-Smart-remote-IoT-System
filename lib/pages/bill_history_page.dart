import 'package:flutter/material.dart';
import '../constants/constant.dart';

class BillHistoryPage extends StatelessWidget {
  const BillHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill History'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Center(
          child: Text(
            'Bill History Page',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
