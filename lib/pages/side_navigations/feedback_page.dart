import 'package:flutter/material.dart';
import '../../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import '../../widgets/card.dart';
import 'package:go_router/go_router.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  int _rating = 0;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: AppColor.accentGreen,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_1),
          onPressed: () => context.go('/home'),
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We value your feedback',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate your experience:',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (i) => IconButton(
                        icon: Icon(
                          i < _rating ? Iconsax.star1 : Iconsax.star,
                          color: AppColor.accentGreen,
                        ),
                        onPressed: () => setState(() => _rating = i + 1),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Comments or suggestions',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: Insets.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Iconsax.send_2),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Thank you for your feedback!'),
                            backgroundColor: AppColor.accentGreen,
                          ),
                        );
                        setState(() {
                          _rating = 0;
                          _controller.clear();
                        });
                      },
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
