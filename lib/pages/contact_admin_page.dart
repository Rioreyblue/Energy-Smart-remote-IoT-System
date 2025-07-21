import 'package:flutter/material.dart';
import '../constants/constant.dart';

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
        child: Center(
          child: Text(
            'Contact Admin / Helpdesk Page',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
