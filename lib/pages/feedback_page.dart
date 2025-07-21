import 'package:flutter/material.dart';
import '../constants/constant.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Center(
          child: Text(
            'Feedback Page',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
