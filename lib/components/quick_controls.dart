import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:provider/provider.dart';
import 'switch_card.dart';
import '../controllers/home_controller.dart';
import '../models/appliance_model.dart';
import '../services/goals_service.dart';
import '../utils/snackbar_utils.dart';

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

    // Display name can be customized per user without changing ESP32 DB paths.
    final displayName =
        controller.applianceAliases[appliance.id] ?? appliance.name;

    return SwitchCard(
      name: displayName,
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
      onLongPress: () async {
        if (!isUserTypeEmpty) {
          await _showRenameDialog(context, controller, appliance, displayName);
        }
      },
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    HomeController controller,
    ApplianceModel appliance,
    String currentName,
  ) async {
    final textController = TextEditingController(text: currentName);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Available icon options (7 icons)
    final iconOptions = [
      {'name': 'Lamp', 'icon': Iconsax.lamp, 'value': 'Iconsax.lamp'},
      {
        'name': 'Lamp Charge',
        'icon': Iconsax.lamp_charge,
        'value': 'Iconsax.lamp_charge',
      },
      {'name': 'Wind/Fan', 'icon': Iconsax.wind, 'value': 'Iconsax.fan'},
      {'name': 'Monitor', 'icon': Iconsax.monitor, 'value': 'Iconsax.monitor'},
      {'name': 'Coffee', 'icon': Iconsax.coffee, 'value': 'Iconsax.coffee'},
      {
        'name': 'Electricity',
        'icon': Iconsax.electricity,
        'value': 'Iconsax.socket',
      },
      {'name': 'Home', 'icon': Iconsax.home, 'value': 'Iconsax.home'},
    ];

    String selectedIcon = appliance.icon;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              backgroundColor: Theme.of(builderContext).colorScheme.surface,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isDark
                            ? AppColor.accentGreen.withAlpha(77)
                            : Theme.of(
                              builderContext,
                            ).colorScheme.outline.withAlpha(77),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? Colors.black.withAlpha((0.3 * 255).toInt())
                              : Colors.black.withAlpha((0.05 * 255).toInt()),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(builderContext).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(Insets.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and title
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(Insets.md),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? AppColor.accentGreen
                                      : Theme.of(context).colorScheme.primary)
                                  .withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Iconsax.edit_2,
                              color:
                                  isDark
                                      ? AppColor.accentGreen
                                      : Theme.of(
                                        builderContext,
                                      ).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: Insets.md),
                          Expanded(
                            child: Text(
                              'Rename Device',
                              style: ResponsiveText.title(
                                builderContext,
                              ).copyWith(
                                color:
                                    Theme.of(
                                      builderContext,
                                    ).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Iconsax.close_circle,
                              color: Theme.of(
                                builderContext,
                              ).colorScheme.onSurface.withAlpha(153),
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      SizedBox(height: Insets.lg),

                      // Icon Selection
                      Text(
                        'Select Icon',
                        style: ResponsiveText.label(builderContext).copyWith(
                          color: Theme.of(builderContext).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: Insets.sm),
                      Wrap(
                        spacing: Insets.sm,
                        runSpacing: Insets.sm,
                        children:
                            iconOptions.map((option) {
                              final isSelected =
                                  selectedIcon == option['value'];
                              return GestureDetector(
                                onTap: () {
                                  if (builderContext.mounted) {
                                    setState(() {
                                      selectedIcon = option['value'] as String;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? (isDark
                                                    ? AppColor.accentGreen
                                                    : Theme.of(
                                                      builderContext,
                                                    ).colorScheme.primary)
                                                .withAlpha(26)
                                            : Theme.of(builderContext)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withAlpha(77),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? (isDark
                                                  ? AppColor.accentGreen
                                                  : Theme.of(
                                                    builderContext,
                                                  ).colorScheme.primary)
                                              : Theme.of(builderContext)
                                                  .colorScheme
                                                  .outline
                                                  .withAlpha(77),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Icon(
                                    option['icon'] as IconData,
                                    color:
                                        isSelected
                                            ? (isDark
                                                ? AppColor.accentGreen
                                                : Theme.of(
                                                  builderContext,
                                                ).colorScheme.primary)
                                            : Theme.of(builderContext)
                                                .colorScheme
                                                .onSurface
                                                .withAlpha(153),
                                    size: 24,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      SizedBox(height: Insets.md),

                      // Input field
                      Text(
                        'Device Name',
                        style: ResponsiveText.label(builderContext).copyWith(
                          color: Theme.of(builderContext).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: Insets.sm),
                      TextField(
                        controller: textController,
                        autofocus: false,
                        maxLength: 25,
                        onChanged: (_) {
                          if (builderContext.mounted) {
                            setState(() {});
                          }
                        },
                        style: ResponsiveText.body(builderContext).copyWith(
                          color: Theme.of(builderContext).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter device name',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              builderContext,
                            ).colorScheme.onSurface.withAlpha(128),
                          ),
                          prefixIcon: Icon(
                            Iconsax.tag,
                            color:
                                isDark
                                    ? AppColor.accentGreen
                                    : Theme.of(
                                      builderContext,
                                    ).colorScheme.primary,
                          ),
                          suffixIcon:
                              textController.text.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Iconsax.close_circle,
                                      color: Theme.of(
                                        builderContext,
                                      ).colorScheme.onSurface.withAlpha(128),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      textController.clear();
                                      if (builderContext.mounted) {
                                        setState(() {});
                                      }
                                    },
                                  )
                                  : null,
                          counterText: '',
                          filled: true,
                          fillColor:
                              Theme.of(builderContext).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(
                                builderContext,
                              ).colorScheme.outline.withAlpha(77),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(
                                builderContext,
                              ).colorScheme.outline.withAlpha(77),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppColor.accentGreen
                                      : Theme.of(
                                        builderContext,
                                      ).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Insets.lg),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: Insets.md,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withAlpha(77),
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: ResponsiveText.body(
                                  builderContext,
                                ).copyWith(
                                  color:
                                      Theme.of(
                                        builderContext,
                                      ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: Insets.md),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColor.accentGreen,
                                    AppColor.lowConsumption,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Close dialog first to prevent state issues
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).pop();

                                  // Perform updates after dialog is closed
                                  try {
                                    final newName = textController.text.trim();

                                    // Update icon if changed
                                    if (selectedIcon != appliance.icon) {
                                      await controller.updateAppliance(
                                        appliance.id,
                                        {'icon': selectedIcon},
                                      );
                                    }

                                    // Update name alias
                                    if (newName.isNotEmpty &&
                                        newName != currentName) {
                                      await controller.setApplianceAlias(
                                        appliance.id,
                                        newName,
                                      );
                                    } else if (newName.isEmpty &&
                                        currentName.isNotEmpty) {
                                      await controller.clearApplianceAlias(
                                        appliance.id,
                                      );
                                    }
                                  } catch (e) {
                                    // Show error in parent context if available
                                    if (context.mounted) {
                                      showErrorSnackBar(
                                        context,
                                        'Failed to update device. Please try again.',
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(
                                    vertical: Insets.md,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Iconsax.tick_circle,
                                      color:
                                          Theme.of(
                                            builderContext,
                                          ).colorScheme.onPrimary,
                                      size: 20,
                                    ),
                                    SizedBox(width: Insets.sm),
                                    Text(
                                      'Save',
                                      style: ResponsiveText.body(
                                        builderContext,
                                      ).copyWith(
                                        color:
                                            Theme.of(
                                              builderContext,
                                            ).colorScheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Dispose controller when dialog is closed
      textController.dispose();
    });
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
