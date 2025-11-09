// import 'package:flutter/material.dart';
// import 'package:exercise_app/constants/constant.dart';
// import 'package:iconsax/iconsax.dart';
// import '../services/usage_service.dart';
// import '../services/rates_service.dart';
// import '../controllers/energy_dashboard_controller.dart';
// import '../widgets/animated_number_widget.dart';

// class EnergyOverviewCard extends StatefulWidget {
//   final double Function(BuildContext, double) responsiveFontSize;
//   const EnergyOverviewCard({required this.responsiveFontSize, super.key});

//   @override
//   State<EnergyOverviewCard> createState() => _EnergyOverviewCardState();
// }

// class _EnergyOverviewCardState extends State<EnergyOverviewCard> {
//   late EnergyDashboardController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = EnergyDashboardController();
//     _controller.initialize();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<Map<String, dynamic>>(
//       stream: UsageService().listenToTodayUsage(),
//       builder: (context, usageSnapshot) {
//         if (usageSnapshot.connectionState == ConnectionState.waiting) {
//           return const _LoadingCard();
//         }

//         if (usageSnapshot.hasError) {
//           return _ErrorCard(error: usageSnapshot.error.toString());
//         }

//         if (!usageSnapshot.hasData) {
//           return const _LoadingCard();
//         }

//         final todayUsage = usageSnapshot.data!;

//         return StreamBuilder<double>(
//           stream: RatesService().listenToCurrentRate(),
//           builder: (context, rateSnapshot) {
//             if (rateSnapshot.connectionState == ConnectionState.waiting) {
//               return const _LoadingCard();
//             }

//             final currentRate = rateSnapshot.data ?? 12.50;

//             return ListenableBuilder(
//               listenable: _controller,
//               builder: (context, child) {
//                 // Calculate current usage (kWh from today's usage)
//                 final currentUsage = todayUsage['totalKwh'] ?? 0.0;
//                 final conversionValue = currentUsage * currentRate;

//                 // Get today's cost
//                 final todaysCost = todayUsage['totalCost'] ?? 0.0;

//                 // Get target cost from EnergyDashboardController
//                 final targetCost = _controller.targetCost;

//                 // For now, use today's cost as this month (will be replaced with proper monthly data)
//                 final thisMonth = todaysCost;

//                 return _EnergyCard(
//                   responsiveFontSize: widget.responsiveFontSize,
//                   currentUsage: currentUsage,
//                   conversionValue: conversionValue,
//                   todaysCost: todaysCost,
//                   targetCost: targetCost,
//                   thisMonth: thisMonth,
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
// }

// class _EnergyCard extends StatelessWidget {
//   final double Function(BuildContext, double) responsiveFontSize;
//   final double currentUsage;
//   final double conversionValue;
//   final double todaysCost;
//   final double targetCost;
//   final double thisMonth;

//   const _EnergyCard({
//     required this.responsiveFontSize,
//     required this.currentUsage,
//     required this.conversionValue,
//     required this.todaysCost,
//     required this.targetCost,
//     required this.thisMonth,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(Insets.xm - 1),
//       decoration: BoxDecoration(
//         color: AppColor.accentGreen.withAlpha(128),
//         borderRadius: BorderRadius.circular(Insets.lg),
//       ),
//       child: Container(
//         padding: EdgeInsets.all(Insets.lg),
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [AppColor.lowConsumption, AppColor.accentGreen],
//           ),
//           borderRadius: BorderRadius.all(Radius.circular(16)),
//           boxShadow: [
//             BoxShadow(
//               color: Color.fromARGB(
//                 77,
//                 16,
//                 185,
//                 129,
//               ), // AppColor.lowConsumption.withAlpha(77)
//               blurRadius: 20,
//               offset: Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const _HeaderRow(),
//             SizedBox(height: Insets.sm),
//             _UsageRow(
//               responsiveFontSize: responsiveFontSize,
//               currentUsage: currentUsage,
//               conversionValue: conversionValue,
//             ),
//             SizedBox(height: Insets.lg),
//             Row(
//               children: [
//                 Expanded(
//                   child: _StatCard(
//                     responsiveFontSize: responsiveFontSize,
//                     label: 'Today\'s Cost',
//                     value: todaysCost,
//                     icon: Iconsax.money,
//                   ),
//                 ),
//                 SizedBox(width: Insets.sm),
//                 Expanded(
//                   child: _StatCard(
//                     responsiveFontSize: responsiveFontSize,
//                     label: 'Target Cost',
//                     value: targetCost,
//                     icon: Iconsax.flag,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: Insets.sm),
//             _StatCard(
//               responsiveFontSize: responsiveFontSize,
//               label: 'This Month',
//               value: thisMonth,
//               icon: Iconsax.calendar,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _HeaderRow extends StatelessWidget {
//   const _HeaderRow();

//   @override
//   Widget build(BuildContext context) {
//     return const Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           'Current Usage',
//           style: TextStyle(
//             color: Color.fromARGB(
//               179,
//               255,
//               255,
//               255,
//             ), // Colors.white.withAlpha(179)
//             fontSize: 16,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         _LiveIndicator(),
//       ],
//     );
//   }
// }

// class _LiveIndicator extends StatelessWidget {
//   const _LiveIndicator();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: const Color.fromARGB(
//           51,
//           255,
//           255,
//           255,
//         ), // Colors.white.withAlpha(51)
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: const Text(
//         'Live',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 12,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     );
//   }
// }

// class _UsageRow extends StatelessWidget {
//   final double Function(BuildContext, double) responsiveFontSize;
//   final double currentUsage;
//   final double conversionValue;

//   const _UsageRow({
//     required this.responsiveFontSize,
//     required this.currentUsage,
//     required this.conversionValue,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(
//           child: _AnimatedNumberText(
//             value: currentUsage,
//             suffix: 'kWh',
//             fontSize: responsiveFontSize(context, 32),
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         const SizedBox(width: Insets.xm),
//         _CostContainer(
//           responsiveFontSize: responsiveFontSize,
//           conversionValue: conversionValue,
//         ),
//       ],
//     );
//   }
// }

// class _AnimatedNumberText extends StatelessWidget {
//   final double value;
//   final String suffix;
//   final double fontSize;
//   final FontWeight fontWeight;
//   final Color color;

//   const _AnimatedNumberText({
//     required this.value,
//     required this.suffix,
//     required this.fontSize,
//     required this.fontWeight,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         AnimatedNumberWidget(
//           value: value,
//           style: TextStyle(
//             color: color,
//             fontSize: fontSize,
//             fontWeight: fontWeight,
//           ),
//           fractionDigits: 2,
//         ),
//         const SizedBox(width: Insets.xm),
//         Text(
//           suffix,
//           style: TextStyle(
//             color: color.withAlpha(204),
//             fontSize: fontSize * 0.5,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _CostContainer extends StatelessWidget {
//   final double Function(BuildContext, double) responsiveFontSize;
//   final double conversionValue;

//   const _CostContainer({
//     required this.responsiveFontSize,
//     required this.conversionValue,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: const Color.fromARGB(
//           51,
//           255,
//           255,
//           255,
//         ), // Colors.white.withAlpha(51)
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: AnimatedCurrencyWidget(
//         value: conversionValue,
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: responsiveFontSize(context, 14),
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     );
//   }
// }

// class _StatCard extends StatelessWidget {
//   final double Function(BuildContext, double) responsiveFontSize;
//   final String label;
//   final double value;
//   final IconData icon;

//   const _StatCard({
//     required this.responsiveFontSize,
//     required this.label,
//     required this.value,
//     required this.icon,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(Insets.md),
//       decoration: BoxDecoration(
//         color: const Color.fromARGB(
//           38,
//           255,
//           255,
//           255,
//         ), // Colors.white.withAlpha(38)
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 icon,
//                 color: const Color.fromARGB(
//                   204,
//                   255,
//                   255,
//                   255,
//                 ), // Colors.white.withAlpha(204)
//                 size: 16,
//               ),
//               SizedBox(width: Insets.xm),
//               Expanded(
//                 child: Text(
//                   label,
//                   style: TextStyle(
//                     color: const Color.fromARGB(
//                       179,
//                       255,
//                       255,
//                       255,
//                     ), // Colors.white.withAlpha(179)
//                     fontSize: responsiveFontSize(context, 12),
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: Insets.xm),
//           AnimatedCurrencyWidget(
//             value: value,
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: responsiveFontSize(context, 16),
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _LoadingCard extends StatelessWidget {
//   const _LoadingCard();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(Insets.lg),
//       decoration: BoxDecoration(
//         color: AppColor.accentGreen.withAlpha(128),
//         borderRadius: BorderRadius.circular(Insets.lg),
//       ),
//       child: const Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//         ),
//       ),
//     );
//   }
// }

// class _ErrorCard extends StatelessWidget {
//   final String error;

//   const _ErrorCard({required this.error});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(Insets.lg),
//       decoration: BoxDecoration(
//         color: AppColor.accentRed.withAlpha(128),
//         borderRadius: BorderRadius.circular(Insets.lg),
//       ),
//       child: Column(
//         children: [
//           const Icon(Iconsax.warning_2, color: Colors.white, size: 32),
//           SizedBox(height: Insets.sm),
//           const Text(
//             'Error loading data',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           SizedBox(height: Insets.xm),
//           Text(
//             error,
//             style: const TextStyle(
//               color: Color.fromARGB(
//                 204,
//                 255,
//                 255,
//                 255,
//               ), // Colors.white.withAlpha(204)
//               fontSize: 12,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// }
