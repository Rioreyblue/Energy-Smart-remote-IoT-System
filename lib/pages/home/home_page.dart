import 'dart:async';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/components/quick_controls.dart';
import 'package:exercise_app/components/scene_modes.dart' as scene_models;
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:exercise_app/components/header.dart';
import 'package:exercise_app/components/optimized_energy_overview_card.dart';
import 'package:exercise_app/components/activity_section.dart';
import 'package:exercise_app/components/energy_insights.dart';
import 'package:exercise_app/controllers/home_controller.dart';
import 'package:exercise_app/controllers/energy_dashboard_controller.dart';
import 'package:exercise_app/controllers/chat_notification_controller.dart';
import 'package:exercise_app/controllers/budget_controller.dart';
import 'package:exercise_app/services/scene_service.dart';
import 'package:exercise_app/models/scene_model.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToMonitoring;

  const HomePage({this.onNavigateToMonitoring, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final SceneService _sceneService = SceneService();
  String _activeScene = '';
  bool _isExecutingScene = false;
  late AnimationController _sceneAnimationController;
  late Animation<double> _sceneAnimation;

  @override
  void initState() {
    super.initState();
    _sceneAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sceneAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sceneAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize the home controller, energy dashboard controller, budget controller, and chat notification controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().initialize();
      context.read<EnergyDashboardController>().initialize();
      context.read<BudgetController>().init();
      context.read<ChatNotificationController>().initialize();
      _initializeScenes();
    });
  }

  Future<void> _initializeScenes() async {
    try {
      // Initialize default scenes for new users
      await _sceneService.initializeDefaultScenes();
    } catch (e) {
      debugPrint('Error initializing scenes: $e');
      // Don't show error to user as this is a background operation
      // Scenes will be initialized automatically when needed
    }
  }

  @override
  void dispose() {
    _sceneAnimationController.dispose();
    super.dispose();
  }

  double _responsiveFontSize(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    return base * (width / 375.0).clamp(0.85, 1.2);
  }

  // Helper method to convert icon string to IconData
  IconData _getIconData(String iconString) {
    switch (iconString) {
      case 'Iconsax.home':
        return Iconsax.home;
      case 'Iconsax.logout':
        return Iconsax.logout;
      case 'Iconsax.moon':
        return Iconsax.moon;
      case 'Iconsax.tree':
        return Iconsax.tree;
      case 'Iconsax.monitor':
        return Iconsax.monitor;
      case 'Iconsax.lamp':
        return Iconsax.lamp;
      case 'Iconsax.wind':
        return Iconsax.wind;
      case 'Iconsax.drop':
        return Iconsax.drop;
      default:
        return Iconsax.home;
    }
  }

  // Execute scene using the new SceneService with smooth animation, timeout, and retry logic
  Future<void> _executeScene(String sceneId, String sceneName) async {
    if (_isExecutingScene) {
      debugPrint(
        'Scene execution already in progress, ignoring duplicate request',
      );
      return;
    }

    // Start animation
    _sceneAnimationController.forward();

    setState(() {
      _isExecutingScene = true;
      _activeScene = sceneName;
    });

    const maxRetries = 2;
    const timeoutDuration = Duration(seconds: 30);
    int attempt = 0;
    bool success = false;

    while (attempt <= maxRetries && !success && mounted) {
      try {
        attempt++;
        debugPrint(
          'Executing scene $sceneName (attempt $attempt/${maxRetries + 1})',
        );

        // Execute scene with timeout
        await _sceneService
            .executeScene(sceneId)
            .timeout(
              timeoutDuration,
              onTimeout: () {
                throw TimeoutException(
                  'Scene execution timed out after ${timeoutDuration.inSeconds} seconds',
                  timeoutDuration,
                );
              },
            );

        success = true;

        // Show success feedback with smooth animation
        if (mounted) {
          // Refresh appliances to update QuickControls immediately
          await context.read<HomeController>().refreshAppliances();

          _showAnimatedSnackBar(
            message: '$sceneName activated successfully!',
            backgroundColor: AppColor.lowConsumption,
          );

          // Keep active scene state for visual feedback
          // The active scene will remain highlighted until another scene is activated
        }
      } catch (error) {
        debugPrint('Scene execution attempt $attempt failed: $error');

        if (attempt <= maxRetries) {
          // Wait before retrying (exponential backoff)
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          debugPrint('Retrying scene execution...');
        } else {
          // All retries failed
          if (mounted) {
            String errorMessage = 'Failed to execute scene';
            if (error is TimeoutException) {
              errorMessage = 'Scene execution timed out. Please try again.';
            } else if (error.toString().contains('Scene not found')) {
              errorMessage = 'Scene not found. Please refresh the page.';
            } else if (error.toString().contains('No appliances found')) {
              errorMessage =
                  'No appliances configured. Please add appliances first.';
            } else {
              errorMessage =
                  'Failed to execute scene: ${error.toString().split('\n').first}';
            }

            _showAnimatedSnackBar(
              message: errorMessage,
              backgroundColor: AppColor.highConsumption,
            );
          }
        }
      }
    }

    // Always reset animation and execution state
    if (mounted) {
      _sceneAnimationController.reverse();
      setState(() {
        _isExecutingScene = false;
        // Only clear active scene if execution failed
        if (!success) {
          _activeScene = '';
        }
      });
    }
  }

  void _showAnimatedSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(message, key: ValueKey(message)),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
            const _HeaderSection(),
            SizedBox(height: Insets.lg),
            OptimizedEnergyOverviewCard(
              responsiveFontSize: _responsiveFontSize,
            ),
            SizedBox(height: Insets.md),
            QuickControls(responsiveFontSize: _responsiveFontSize),
            SizedBox(height: Insets.md),
            _SceneModesSection(
              sceneService: _sceneService,
              activeScene: _activeScene,
              isExecutingScene: _isExecutingScene,
              sceneAnimation: _sceneAnimation,
              onSceneExecuted: _executeScene,
              getIconData: _getIconData,
              responsiveFontSize: _responsiveFontSize,
            ),
            SizedBox(height: Insets.md),
            ActivitySection(responsiveFontSize: _responsiveFontSize),
            SizedBox(height: Insets.md),
            EnergyInsights(
              responsiveFontSize: _responsiveFontSize,
              onViewAllPressed: widget.onNavigateToMonitoring,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Header(
      responsiveFontSize: (context, base) {
        final width = MediaQuery.of(context).size.width;
        return base * (width / 375.0).clamp(0.85, 1.2);
      },
    );
  }
}

class _SceneModesSection extends StatelessWidget {
  final SceneService sceneService;
  final String activeScene;
  final bool isExecutingScene;
  final Animation<double> sceneAnimation;
  final Future<void> Function(String sceneId, String sceneName) onSceneExecuted;
  final IconData Function(String iconString) getIconData;
  final double Function(BuildContext, double) responsiveFontSize;

  const _SceneModesSection({
    required this.sceneService,
    required this.activeScene,
    required this.isExecutingScene,
    required this.sceneAnimation,
    required this.onSceneExecuted,
    required this.getIconData,
    required this.responsiveFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SceneModel>>(
      stream: sceneService.listenToScenes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SceneLoadingWidget();
        }

        if (snapshot.hasError) {
          return _SceneErrorWidget(error: snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _SceneEmptyWidget();
        }

        final scenes = snapshot.data!;
        return AnimatedBuilder(
          animation: sceneAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.95 + (0.05 * sceneAnimation.value),
              child: Opacity(
                opacity: 0.8 + (0.2 * sceneAnimation.value),
                child: scene_models.SceneModes(
                  scenePresets:
                      scenes
                          .map(
                            (scene) => scene_models.ScenePreset(
                              name: scene.name,
                              icon: getIconData(scene.icon),
                              deviceStates: scene.deviceStates.map(
                                (key, value) => MapEntry(
                                  key,
                                  scene_models.DeviceState(
                                    isOn: value.isOn,
                                    value: value.value,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  activeScene: activeScene,
                  isLoading: isExecutingScene,
                  onSceneExecuted: (sceneName, deviceStates) async {
                    try {
                      // Find the scene by name and execute it
                      final scene = scenes.firstWhere(
                        (s) => s.name == sceneName,
                        orElse: () {
                          // If scene not found by name, try to find by ID or return first
                          debugPrint(
                            'Scene "$sceneName" not found in list, using first scene',
                          );
                          return scenes.first;
                        },
                      );
                      await onSceneExecuted(scene.id, sceneName);
                    } catch (e) {
                      debugPrint('Error executing scene: $e');
                      // Error will be handled in _executeScene method
                    }
                  },
                  responsiveFontSize: responsiveFontSize,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SceneLoadingWidget extends StatelessWidget {
  const _SceneLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Insets.lg),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SceneErrorWidget extends StatelessWidget {
  final String error;

  const _SceneErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(Insets.lg),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.warning_2,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Error loading scenes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onErrorContainer.withAlpha(179),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneEmptyWidget extends StatelessWidget {
  const _SceneEmptyWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Insets.lg),
      ),
      child: Center(
        child: Column(  
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.home,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No scenes available',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
