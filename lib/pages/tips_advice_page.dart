import 'package:flutter/material.dart';
import '../constants/constant.dart';

class TipsAdvicePage extends StatelessWidget {
  const TipsAdvicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tips & Advice'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Center(
          child: Text(
            'Tips & Advice Page',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
