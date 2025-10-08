import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/components/quick_controls.dart';
import 'package:exercise_app/components/scene_modes.dart' as scene_models;
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
// import 'package:exercise_app/pages/scene_edit_page.dart';
import 'package:exercise_app/components/header.dart';
import 'package:exercise_app/components/energy_overview_card.dart';
import 'package:exercise_app/components/activity_section.dart';
import 'package:exercise_app/components/energy_insights.dart';
import 'package:exercise_app/controllers/home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Updated scene presets using the new structure
  late final List<scene_models.ScenePreset> _scenePresets;
  String _activeScene = 'Home Mode';
  bool _isExecutingScene = false;

  @override
  void initState() {
    super.initState();
    _initializeScenePresets();
    // Initialize the home controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().initialize();
    });
  }

  void _initializeScenePresets() {
    _scenePresets = [
      scene_models.ScenePreset(
        name: 'Home Mode',
        icon: Iconsax.home,
        deviceStates: {
          'Air Conditioner': const scene_models.DeviceState(
            isOn: true,
            value: 0.8,
          ),
          'Water Heater': const scene_models.DeviceState(isOn: false),
          'Living Room': const scene_models.DeviceState(isOn: true, value: 1.0),
          'Kitchen': const scene_models.DeviceState(isOn: true, value: 0.9),
        },
      ),
      scene_models.ScenePreset(
        name: 'Away Mode',
        icon: Iconsax.logout,
        deviceStates: {
          'Air Conditioner': const scene_models.DeviceState(isOn: false),
          'Water Heater': const scene_models.DeviceState(isOn: false),
          'Living Room': const scene_models.DeviceState(isOn: false),
          'Kitchen': const scene_models.DeviceState(isOn: false),
        },
      ),
      scene_models.ScenePreset(
        name: 'Sleep Mode',
        icon: Iconsax.moon,
        deviceStates: {
          'Air Conditioner': const scene_models.DeviceState(isOn: false),
          'Water Heater': const scene_models.DeviceState(isOn: false),
          'Living Room': const scene_models.DeviceState(isOn: false),
          'Kitchen': const scene_models.DeviceState(isOn: true, value: 0.3),
        },
      ),
      scene_models.ScenePreset(
        name: 'Eco Mode',
        icon: Iconsax.tree,
        deviceStates: {
          'Air Conditioner': const scene_models.DeviceState(
            isOn: true,
            value: 0.5,
          ),
          'Water Heater': const scene_models.DeviceState(isOn: false),
          'Living Room': const scene_models.DeviceState(isOn: false),
          'Kitchen': const scene_models.DeviceState(isOn: false),
        },
      ),
      scene_models.ScenePreset(
        name: 'Work Mode',
        icon: Iconsax.monitor,
        deviceStates: {
          'Air Conditioner': const scene_models.DeviceState(
            isOn: true,
            value: 0.7,
          ),
          'Water Heater': const scene_models.DeviceState(isOn: true),
          'Living Room': const scene_models.DeviceState(isOn: true, value: 1.0),
          'Kitchen': const scene_models.DeviceState(isOn: true, value: 0.8),
        },
      ),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  double _responsiveFontSize(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    return base * (width / 375.0).clamp(0.85, 1.2);
  }

  // Updated scene execution method
  Future<void> _executeScenePreset(
    String sceneName,
    Map<String, scene_models.DeviceState> deviceStates,
  ) async {
    if (_isExecutingScene) return;

    setState(() {
      _isExecutingScene = true;
      _activeScene = sceneName;
    });

    try {
      // Simulate scene execution delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Apply device states to appliances
      final controller = context.read<HomeController>();
      for (final appliance in controller.appliances) {
        final deviceState = deviceStates[appliance.name];
        if (deviceState != null) {
          await controller.toggleAppliance(appliance.uid, deviceState.isOn);
        }
      }

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sceneName activated successfully!'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColor.lowConsumption,
          ),
        );
      }
    } catch (error) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to execute scene: $error'),
            backgroundColor: AppColor.highConsumption,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExecutingScene = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Header(
              username: 'Rey Francisco',
              responsiveFontSize: _responsiveFontSize,
            ),
            SizedBox(height: Insets.lg),
            EnergyOverviewCard(responsiveFontSize: _responsiveFontSize),
            SizedBox(height: Insets.md),
            QuickControls(responsiveFontSize: _responsiveFontSize),
            SizedBox(height: Insets.md),
            // Updated SceneModes widget with edit navigation
            scene_models.SceneModes(
              scenePresets: _scenePresets,
              activeScene: _activeScene,
              isLoading: _isExecutingScene,
              onSceneExecuted: _executeScenePreset,
              responsiveFontSize: _responsiveFontSize,
            ),
            SizedBox(height: Insets.md),
            ActivitySection(responsiveFontSize: _responsiveFontSize),
            SizedBox(height: Insets.md),
            EnergyInsights(responsiveFontSize: _responsiveFontSize),
          ],
        ),
      ),
    );
  }
}
