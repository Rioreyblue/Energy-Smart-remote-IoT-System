import 'package:flutter/material.dart';
import '../constants/constant.dart';

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
        child: Center(
          child: Text(
            'Data Management Page',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
