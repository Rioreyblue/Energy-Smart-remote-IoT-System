import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:provider/provider.dart';
import 'switch_card.dart';
import '../controllers/home_controller.dart';
import '../models/appliance_model.dart';
import '../services/goals_service.dart';

class QuickControls extends StatefulWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const QuickControls({required this.responsiveFontSize, super.key});

  @override
  State<QuickControls> createState() => _QuickControlsState();
}

class _QuickControlsState extends State<QuickControls> {
  final GoalsService _goalsService = GoalsService();
  String? _userType;

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh userType when page becomes visible again
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final result = await _goalsService.getUserType();
    if (mounted) {
      setState(() {
        _userType = result.data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        final appliances = controller.appliances;
        final isUserTypeEmpty = _userType == null || _userType!.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Controls',
              style: TextStyle(
                fontSize: widget.responsiveFontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: Insets.md),
            if (appliances.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDeviceCard(
                      context,
                      appliances[0],
                      controller,
                      isUserTypeEmpty,
                    ),
                  ),
                  SizedBox(width: Insets.sm),
                  Expanded(
                    child:
                        appliances.length > 1
                            ? _buildDeviceCard(
                              context,
                              appliances[1],
                              controller,
                              isUserTypeEmpty,
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
                              isUserTypeEmpty,
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
                              isUserTypeEmpty,
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
    bool isUserTypeEmpty,
  ) {
    // Use dynamic rate from Firestore (admin_settings/system_config/powerRate)
    final cost = appliance.formatCost(controller.currentRate);
    final timerText = _formatTimerText(appliance);

    return SwitchCard(
      name: appliance.name,
      icon: appliance.getIconData(),
      isOn: appliance.isOn,
      label: 'Cost',
      cost: cost,
      timerText: timerText,
      enabled: !isUserTypeEmpty,
      onToggle: (value) {
        if (!isUserTypeEmpty) {
          controller.toggleAppliance(appliance.id, value);
        }
      },
    );
  }

  // Optimized timer text formatting - cache calculation
  String _formatTimerText(ApplianceModel appliance) {
    if (!appliance.isOn ||
        appliance.startTime == null ||
        appliance.startTime!.isEmpty) {
      return '0:00:00:00';
    }

    try {
      final startTime = DateTime.parse(appliance.startTime!);
      final duration = DateTime.now().difference(startTime);

      // Return formatted duration efficiently
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
