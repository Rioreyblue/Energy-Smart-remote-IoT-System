import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'switch_card.dart';

class QuickDeviceState {
  final String name;
  final IconData icon;
  final bool isOn;
  final String label;
  final String cost;
  final String timerText;
  QuickDeviceState({
    required this.name,
    required this.icon,
    required this.isOn,
    required this.label,
    required this.cost,
    required this.timerText,
  });
}

class QuickControls extends StatelessWidget {
  final List<QuickDeviceState> devices;
  final void Function(int, bool) onToggle;
  final double Function(BuildContext, double) responsiveFontSize;
  const QuickControls({
    required this.devices,
    required this.onToggle,
    required this.responsiveFontSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
        Row(
          children: [
            Expanded(child: _buildDeviceCard(context, 0)),
            SizedBox(width: Insets.sm),
            Expanded(child: _buildDeviceCard(context, 1)),
          ],
        ),
        SizedBox(height: Insets.sm),
        Row(
          children: [
            Expanded(child: _buildDeviceCard(context, 2)),
            SizedBox(width: Insets.sm),
            Expanded(child: _buildDeviceCard(context, 3)),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceCard(BuildContext context, int index) {
    final device = devices[index];
    return SwitchCard(
      name: device.name,
      icon: device.icon,
      isOn: device.isOn,
      label: device.label,
      cost: device.cost,
      timerText: device.timerText,
      onToggle: (value) => onToggle(index, value),
    );
  }
}
