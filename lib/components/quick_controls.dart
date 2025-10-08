import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:provider/provider.dart';
import 'switch_card.dart';
import '../controllers/home_controller.dart';
import '../models/appliance_model.dart';

class QuickControls extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const QuickControls({required this.responsiveFontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        final appliances = controller.appliances;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Controls',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: Insets.md),
            if (appliances.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDeviceCard(context, appliances[0], controller),
                  ),
                  SizedBox(width: Insets.sm),
                  Expanded(
                    child:
                        appliances.length > 1
                            ? _buildDeviceCard(
                              context,
                              appliances[1],
                              controller,
                            )
                            : const SizedBox(),
                  ),
                ],
              ),
              SizedBox(height: Insets.sm),
              Row(
                children: [
                  Expanded(
                    child:
                        appliances.length > 2
                            ? _buildDeviceCard(
                              context,
                              appliances[2],
                              controller,
                            )
                            : const SizedBox(),
                  ),
                  SizedBox(width: Insets.sm),
                  Expanded(
                    child:
                        appliances.length > 3
                            ? _buildDeviceCard(
                              context,
                              appliances[3],
                              controller,
                            )
                            : const SizedBox(),
                  ),
                ],
              ),
            ] else ...[
              const Center(
                child: Text('No appliances found. Please add some devices.'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    ApplianceModel appliance,
    HomeController controller,
  ) {
    final cost = appliance.formatCost(
      12.0,
    ); // Default rate, should be configurable
    final timerText = _formatTimerText(appliance);

    return SwitchCard(
      name: appliance.name,
      icon: appliance.getIconData(),
      isOn: appliance.isOn,
      label: 'Cost',
      cost: cost,
      timerText: timerText,
      onToggle: (value) => controller.toggleAppliance(appliance.uid, value),
    );
  }

  String _formatTimerText(ApplianceModel appliance) {
    if (!appliance.isOn || appliance.startTime.isEmpty) {
      return '0:00:00:00';
    }

    try {
      final startTime = DateTime.parse(appliance.startTime);
      final now = DateTime.now();
      final duration = now.difference(startTime);

      final days = duration.inDays;
      final hours = duration.inHours % 24;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;

      return '$days:${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '0:00:00:00';
    }
  }
}
