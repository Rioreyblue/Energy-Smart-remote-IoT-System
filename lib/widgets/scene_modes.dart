export 'scene_modes.dart' show DeviceState, ScenePreset, SceneCard;
import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';

/// Device state model for managing individual device states (used for both scenes and quick controls)
class DeviceState {
  final bool isOn;
  final double? value; // For dimmable lights, fan speed, etc.

  const DeviceState({required this.isOn, this.value});

  DeviceState copyWith({bool? isOn, double? value}) {
    return DeviceState(isOn: isOn ?? this.isOn, value: value ?? this.value);
  }
}

/// Scene preset configuration
class ScenePreset {
  final String name;
  final IconData icon;
  final Map<String, DeviceState> deviceStates;

  const ScenePreset({
    required this.name,
    required this.icon,
    required this.deviceStates,
  });
}

/// Callback type for scene execution
typedef SceneExecutionCallback =
    Future<void> Function(
      String sceneName,
      Map<String, DeviceState> deviceStates,
    );

/// SceneModes widget displays a horizontal list of scene presets and handles tap/animation/active state
class SceneModes extends StatelessWidget {
  final List<ScenePreset> scenePresets;
  final String activeScene;
  final SceneExecutionCallback onSceneExecuted;
  final double Function(BuildContext, double) responsiveFontSize;
  final bool isLoading;

  const SceneModes({
    required this.scenePresets,
    required this.activeScene,
    required this.onSceneExecuted,
    required this.responsiveFontSize,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scenes & Modes',
          style: TextStyle(
            fontSize: responsiveFontSize(context, 20),
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: Insets.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < scenePresets.length; i++) ...[
                SceneCard(
                  preset: scenePresets[i],
                  isActive: activeScene == scenePresets[i].name,
                  onTap:
                      () => onSceneExecuted(
                        scenePresets[i].name,
                        scenePresets[i].deviceStates,
                      ),
                  isLoading: isLoading && activeScene == scenePresets[i].name,
                ),
                if (i < scenePresets.length - 1) SizedBox(width: Insets.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// SceneCard is exported for use in the edit page.
class SceneCard extends StatefulWidget {
  final ScenePreset preset;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLoading;

  const SceneCard({
    required this.preset,
    required this.isActive,
    required this.onTap,
    this.isLoading = false,
    super.key,
  });

  @override
  State<SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<SceneCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SceneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isActiveState = widget.isActive && !widget.isLoading;
    // Centralized color logic for active/inactive state using AppColor
    final activeBgColor =
        brightness == Brightness.dark ? AppColor.primaryDark : AppColor.primary;
    final activeBorderColor = AppColor.accentGreen;
    final inactiveBgColor =
        brightness == Brightness.dark ? AppColor.surfaceDark : AppColor.surface;
    final inactiveBorderColor = AppColor.disabled;
    final iconColor =
        isActiveState
            ? AppColor.textPrimaryDark
            : (brightness == Brightness.light
                ? AppColor.textPrimary
                : AppColor.textPrimaryDark);
    // final textColor =
    //     isActiveState
    //         ? (brightness == Brightness.dark
    //             ? AppColor.textPrimaryDark
    //             : AppColor.accentGreen)
    //         : AppColor.textPrimary;
    final textColor =
        isActiveState
            ? AppColor.textPrimaryDark
            : (brightness == Brightness.light
                ? AppColor.textPrimary
                : AppColor.textPrimaryDark);

    final backgroundColor = isActiveState ? activeBgColor : inactiveBgColor;
    final borderColor = isActiveState ? activeBorderColor : inactiveBorderColor;
    final shadowColor =
        brightness == Brightness.dark
            ? AppColor.primaryDark.withAlpha(25)
            : AppColor.primary.withAlpha(25);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isLoading ? _pulseAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.md,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: _isPressed ? 2 : 8,
                    offset: Offset(0, _isPressed ? 1 : 4),
                  ),
                  if (isActiveState)
                    BoxShadow(
                      color: activeBorderColor.withAlpha(51),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(widget.preset.icon, color: iconColor, size: 24),
                      if (widget.isLoading)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              iconColor.withAlpha(178),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: Insets.xm),
                  Text(
                    widget.preset.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
