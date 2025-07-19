import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/widgets/quick_controls.dart';
import 'package:exercise_app/widgets/scene_modes.dart' as scene_models;
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:async'; // Added for Timer
import 'package:exercise_app/pages/scene_edit_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Device state and timer tracking
  final List<_DeviceState> _devices = [
    _DeviceState(
      name: 'Air Conditioner',
      icon: Iconsax.element_3,
      isOn: false,
      label: 'cost',
      cost: '₱1.5',
    ),
    _DeviceState(
      name: 'Water Heater',
      icon: Iconsax.drop,
      isOn: false,
      label: 'cost',
      cost: '₱1.5',
    ),
    _DeviceState(
      name: 'Living Room',
      icon: Iconsax.lamp,
      isOn: false,
      label: 'cost',
      cost: '₱1.5',
    ),
    _DeviceState(
      name: 'Kitchen',
      icon: Iconsax.coffee,
      isOn: false,
      label: 'cost',
      cost: '₱1.5',
    ),
  ];

  // Updated scene presets using the new structure
  late final List<scene_models.ScenePreset> _scenePresets;
  String _activeScene = 'Home Mode';
  bool _isExecutingScene = false;

  @override
  void initState() {
    super.initState();
    _initializeScenePresets();
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
    for (final device in _devices) {
      device.dispose();
    }
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

      // Apply device states
      for (int i = 0; i < _devices.length; i++) {
        final deviceName = _devices[i].name;
        final deviceState = deviceStates[deviceName];

        if (deviceState != null) {
          _devices[i].toggle(deviceState.isOn);
          // You can also handle deviceState.value for dimming, fan speed, etc.
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
            _buildHeader(context),
            SizedBox(height: Insets.lg),
            _buildEnergyOverviewCard(context),
            SizedBox(height: Insets.md),
            QuickControls(
              devices:
                  _devices
                      .map(
                        (d) => QuickDeviceState(
                          name: d.name,
                          icon: d.icon,
                          isOn: d.isOn,
                          label: d.label,
                          cost: d.cost,
                          timerText: d.timerText,
                        ),
                      )
                      .toList(),
              onToggle: (index, value) {
                setState(() {
                  _devices[index].toggle(value);
                });
              },
              responsiveFontSize: _responsiveFontSize,
            ),
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
            _buildActivitySection(context),
            SizedBox(height: Insets.md),
            _buildEnergyInsights(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello There!',
              style: TextStyle(
                fontSize: _responsiveFontSize(context, 16),
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              'Rey Francisco', //user name from the email/gmail
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _responsiveFontSize(context, 28),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.05 * 255).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Iconsax.home),
                onPressed: () {},
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(width: Insets.sm),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.05 * 255).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Iconsax.notification),
                onPressed: () {},
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnergyOverviewCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.lowConsumption, AppColor.accentGreen],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColor.lowConsumption.withAlpha((0.3 * 255).toInt()),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Usage',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).toInt()),
                  fontSize: _responsiveFontSize(context, 16),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _responsiveFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.sm),
          Text(
            '2.4 kW',
            style: TextStyle(
              color: Colors.white,
              fontSize: _responsiveFontSize(context, 36),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: Insets.xm),
          Row(
            children: [
              const Icon(Iconsax.trend_down, color: Colors.amber, size: 16),
              SizedBox(width: Insets.xm),
              Text(
                '12% vs yesterday',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.9 * 255).toInt()),
                  fontSize: _responsiveFontSize(context, 14),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOverviewItem(context, "Today's Cost", '₱4.20'),
              _buildOverviewItem(context, 'Target Cost', '₱127.50'),
              _buildOverviewItem(context, 'This Month', '₱127.50'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.8 * 255).toInt()),
            fontSize: _responsiveFontSize(context, 12),
          ),
        ),
        SizedBox(height: Insets.xm),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: _responsiveFontSize(context, 18),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: _responsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: Insets.md),
          _buildActivityItem(
            context,
            Iconsax.lamp,
            'Living room lights turned off',
            '2 min ago',
            AppColor.mediumConsumption,
          ),
          SizedBox(height: Insets.sm),
          _buildActivityItem(
            context,
            Iconsax.cloud_snow,
            'AC temperature set to 22°C',
            '15 min ago',
            AppColor.lowConsumption,
          ),
          SizedBox(height: Insets.sm),
          _buildActivityItem(
            context,
            Iconsax.wallet,
            'Energy goal achieved!',
            '1 hour ago',
            AppColor.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    IconData icon,
    String title,
    String time,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: iconColor.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: _responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: _responsiveFontSize(context, 12),
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnergyInsights(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy Insights',
                style: TextStyle(
                  fontSize: _responsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: _responsiveFontSize(context, 14),
                    color: AppColor.lowConsumption,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          Container(
            padding: EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColor.lowConsumption.withAlpha((0.2 * 255).toInt()),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.lamp_charge,
                  color: AppColor.lowConsumption,
                  size: 20,
                ),
                SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'You can save ₱12 this month by adjusting AC temperature by 2°C',
                    style: TextStyle(
                      fontSize: _responsiveFontSize(context, 14),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for device state and timer
class _DeviceState {
  final String name;
  final IconData icon;
  final String label;
  final String cost;
  bool isOn;
  DateTime? _onStart;
  Duration _elapsed = Duration.zero;
  String timerText = '0:00:00:00';
  Timer? _timer;

  _DeviceState({
    required this.name,
    required this.icon,
    required this.isOn,
    required this.label,
    required this.cost,
  }) {
    if (isOn) {
      _onStart = DateTime.now();
      _startTimer();
    }
  }

  void toggle(bool value) {
    if (value == isOn) return;
    isOn = value;
    if (isOn) {
      _onStart = DateTime.now();
      _startTimer();
    } else {
      _timer?.cancel();
      _elapsed = Duration.zero;
      timerText = '0:00:00:00';
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_onStart != null) {
        final diff = DateTime.now().difference(_onStart!);
        timerText = _formatDuration(diff);
      }
    });
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return '$days:${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _timer?.cancel();
  }
}
