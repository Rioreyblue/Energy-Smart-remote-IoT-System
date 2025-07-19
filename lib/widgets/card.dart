import 'package:exercise_app/constants/constant.dart';
import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double aspectRatio;
  final Color? color;
  final Color? shadowColor;
  final double elevation;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.aspectRatio = 1.0,
    this.color,
    this.shadowColor,
    this.elevation = 2.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.gradient,
    this.border,
    this.boxShadow,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.cardColor;
    final cardShadowColor = shadowColor ?? theme.shadowColor;

    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.symmetric(vertical: Insets.sm),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Material(
          color: gradient != null ? null : cardColor,
          shadowColor: cardShadowColor,
          elevation: elevation,
          borderRadius: borderRadius,
          clipBehavior: clipBehavior,
          child: InkWell(
            // borderRadius: borderRadius,
            onTap: () {}, // Add your onTap logic here
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: borderRadius,
                border: border,
                boxShadow: boxShadow,
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
