import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exercise_app/constants/constant.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _loadingAnimation;

  double _loadingProgress = 0.0;
  final int _loadingDuration = 3500;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _loadingDuration),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeInOut),
      ),
    );

    _animationController.addListener(() {
      setState(() {
        _loadingProgress = _loadingAnimation.value;
      });
    });

    _animationController.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await Future.delayed(Duration(milliseconds: _loadingDuration));

      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding =
          prefs.getBool('seen_onboarding') ??
          prefs.getBool('hasSeenOnboarding') ??
          false;

      if (!mounted) return;

      if (!seenOnboarding) {
        context.go('/onboarding');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        context.go('/error');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColor.primary.withAlpha(51), Colors.white],
          ),
        ),
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: size.width * 0.45,
                            height: size.width * 0.45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColor.accentGreen.withAlpha(77),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: size.width * 0.4,
                            height: size.width * 0.4,
                            padding: EdgeInsets.all(size.width * 0.05),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(26),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icon/update_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'EnergySmart',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          foreground:
                              Paint()
                                ..shader = LinearGradient(
                                  colors: [
                                    AppColor.accentGreen,
                                    AppColor.accentGreen.withAlpha(179),
                                  ],
                                ).createShader(
                                  const Rect.fromLTWH(0, 0, 200, 70),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Smart Energy for Smart Living',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColor.textSecondary.withAlpha(204),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        width: size.width * 0.5,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Row(
                              children: List.generate(
                                20,
                                (index) => const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: _loadingProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColor.accentGreen,
                                      AppColor.accentGreen.withAlpha(204),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColor.accentGreen.withAlpha(128),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColor.textSecondary.withAlpha(
                            _loadingProgress < 1.0 ? 179 : 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
