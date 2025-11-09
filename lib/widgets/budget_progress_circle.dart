import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/constant.dart';

/// Circular progress indicator for budget tracking
class BudgetProgressCircle extends StatelessWidget {
  final double consumedPercentage;
  final double remainingPercentage;
  final String statusColor; // 'normal', 'warning', 'critical'
  final double size;

  const BudgetProgressCircle({
    super.key,
    required this.consumedPercentage,
    required this.remainingPercentage,
    required this.statusColor,
    this.size = 200,
  });

  Color get _progressColor {
    switch (statusColor) {
      case 'normal':
        return AppColor.accentGreen;
      case 'warning':
        return AppColor.mediumConsumption;
      case 'critical':
        return AppColor.accentRed;
      default:
        return AppColor.accentGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 16,
              backgroundColor: AppColor.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.grey.withAlpha(51),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: consumedPercentage / 100,
                  strokeWidth: 16,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                ),
              )
              .animate(target: consumedPercentage > 0 ? 1 : 0)
              .fadeIn(duration: 600.ms)
              .scale(delay: 100.ms),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${remainingPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.bold,
                  color: _progressColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Remaining',
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
