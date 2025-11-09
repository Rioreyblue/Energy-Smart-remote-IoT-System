import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Widget for displaying animated Lottie files in auth screens
class AuthAnimation extends StatefulWidget {
  final String animationPath;
  final double? width;
  final double? height;
  final bool loop;
  final bool reverse;

  const AuthAnimation({
    super.key,
    required this.animationPath,
    this.width,
    this.height,
    this.loop = true,
    this.reverse = false,
  });

  @override
  State<AuthAnimation> createState() => _AuthAnimationState();
}

class _AuthAnimationState extends State<AuthAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Lottie.asset(
          widget.animationPath,
          width: widget.width ?? 350,
          height: widget.height ?? 350,
          repeat: widget.loop,
          reverse: widget.reverse,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if animation fails to load
            return Icon(
              Icons.energy_savings_leaf,
              size: widget.width ?? 350,
              color: Colors.green.withAlpha(77),
            );
          },
        ),
      ),
    );
  }
}
