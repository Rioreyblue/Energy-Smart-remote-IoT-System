import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../controllers/energy_dashboard_controller.dart';
import '../widgets/animated_number_widget.dart';

class OptimizedEnergyOverviewCard extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const OptimizedEnergyOverviewCard({
    required this.responsiveFontSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EnergyDashboardController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return const _LoadingCard();
        }

        if (controller.error != null) {
          return _ErrorCard(error: controller.error!);
        }

        return _EnergyCard(
          responsiveFontSize: responsiveFontSize,
          controller: controller,
        );
      },
    );
  }
}

class _EnergyCard extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  final EnergyDashboardController controller;

  const _EnergyCard({
    required this.responsiveFontSize,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.xm - 1),
      decoration: BoxDecoration(
        color: AppColor.accentGreen.withAlpha(128),
        borderRadius: BorderRadius.circular(Insets.lg),
      ),
      child: Container(
        padding: EdgeInsets.all(Insets.lg),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColor.lowConsumption, AppColor.accentGreen],
          ),
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(77, 16, 185, 129),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeaderRow(),
            SizedBox(height: Insets.sm),
            _UsageRow(
              responsiveFontSize: responsiveFontSize,
              controller: controller,
            ),
            SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    responsiveFontSize: responsiveFontSize,
                    label: 'Today\'s Cost',
                    value: controller.todaysCost,
                    icon: Iconsax.money,
                  ),
                ),
                SizedBox(width: Insets.sm),
                Expanded(
                  child: _StatCard(
                    responsiveFontSize: responsiveFontSize,
                    label: 'Remaining Budget',
                    value: controller.targetCost,
                    icon: Iconsax.flag,
                    showPlaceholder: controller.targetCost == 0,
                  ),
                ),
              ],
            ),
            SizedBox(height: Insets.sm),
            _StatCard(
              responsiveFontSize: responsiveFontSize,
              label: 'This Month',
              value: controller.thisMonth,
              icon: Iconsax.calendar,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Current Usage',
          style: TextStyle(
            color: Color.fromARGB(179, 255, 255, 255),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        _LiveIndicator(),
      ],
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(51, 255, 255, 255),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Live',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  final EnergyDashboardController controller;

  const _UsageRow({required this.responsiveFontSize, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedKwhWidget(
            value: controller.currentUsage,
            style: TextStyle(
              color: Colors.white,
              fontSize: responsiveFontSize(context, 32),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: Insets.xm),
        _CostContainer(
          responsiveFontSize: responsiveFontSize,
          controller: controller,
        ),
      ],
    );
  }
}

class _CostContainer extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  final EnergyDashboardController controller;

  const _CostContainer({
    required this.responsiveFontSize,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromARGB(51, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedCurrencyWidget(
        value: controller.conversionValue,
        style: TextStyle(
          color: Colors.white,
          fontSize: responsiveFontSize(context, 14),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  final String label;
  final double value;
  final IconData icon;
  final bool showPlaceholder;

  const _StatCard({
    required this.responsiveFontSize,
    required this.label,
    required this.value,
    required this.icon,
    this.showPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: const Color.fromARGB(38, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color.fromARGB(204, 255, 255, 255),
                size: 16,
              ),
              SizedBox(width: Insets.xm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: const Color.fromARGB(179, 255, 255, 255),
                    fontSize: responsiveFontSize(context, 12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Insets.xm),
          showPlaceholder
              ? Text(
                'No Target Set',
                style: TextStyle(
                  color: Colors.white.withAlpha(153),
                  fontSize: responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              )
              : AnimatedCurrencyWidget(
                value: value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsiveFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColor.accentGreen.withAlpha(128),
        borderRadius: BorderRadius.circular(Insets.lg),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColor.accentRed.withAlpha(128),
        borderRadius: BorderRadius.circular(Insets.lg),
      ),
      child: Column(
        children: [
          const Icon(Iconsax.warning_2, color: Colors.white, size: 32),
          SizedBox(height: Insets.sm),
          const Text(
            'Error loading data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: Insets.xm),
          Text(
            error,
            style: const TextStyle(
              color: Color.fromARGB(204, 255, 255, 255),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
