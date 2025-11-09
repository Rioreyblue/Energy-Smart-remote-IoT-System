import 'package:flutter/material.dart';
import '../constants/constant.dart';

/// Information card for budget details
class BudgetCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;

  const BudgetCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: iconColor.withAlpha(51), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  title,
                  style: ResponsiveText.label(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            value,
            style: ResponsiveText.title(
              context,
            ).copyWith(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Insets.xm),
            Text(subtitle!, style: ResponsiveText.caption(context)),
          ],
        ],
      ),
    );
  }
}
