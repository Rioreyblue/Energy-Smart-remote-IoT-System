// import 'package:flutter/material.dart';
// import 'package:iconsax/iconsax.dart';
// import '../../constants/constant.dart';

// /// Dialog for setting/updating budget target
// class BudgetSetDialog extends StatefulWidget {
//   final double initialBudget;
//   final double initialThreshold;
//   final Function(double budget, double threshold, bool alertEnabled) onSave;

//   const BudgetSetDialog({
//     super.key,
//     required this.initialBudget,
//     required this.initialThreshold,
//     required this.onSave,
//   });

//   @override
//   State<BudgetSetDialog> createState() => _BudgetSetDialogState();
// }

// class _BudgetSetDialogState extends State<BudgetSetDialog> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _budgetController;
//   late double _threshold;
//   bool _alertEnabled = true;

//   @override
//   void initState() {
//     super.initState();
//     _budgetController = TextEditingController(
//       text:
//           widget.initialBudget > 0
//               ? widget.initialBudget.toStringAsFixed(2)
//               : '',
//     );
//     _threshold = widget.initialThreshold;
//   }

//   @override
//   void dispose() {
//     _budgetController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Set Budget Target'),
//       content: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               TextFormField(
//                 controller: _budgetController,
//                 keyboardType: const TextInputType.numberWithOptions(
//                   decimal: true,
//                 ),
//                 decoration: InputDecoration(
//                   labelText: 'Total Budget (₱)',
//                   hintText: '1000.00',
//                   prefixIcon: const Icon(Iconsax.wallet),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide(color: Colors.grey[300]!),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(
//                       color: AppColor.accentGreen,
//                       width: 2,
//                     ),
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter a budget amount';
//                   }
//                   final budget = double.tryParse(value);
//                   if (budget == null || budget <= 0) {
//                     return 'Please enter a valid amount';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: Insets.lg),
//               Text(
//                 'Alert Threshold: ${_threshold.toStringAsFixed(0)}%',
//                 style: ResponsiveText.body(context),
//               ),
//               Slider(
//                 value: _threshold,
//                 min: 50,
//                 max: 95,
//                 divisions: 9,
//                 label: '${_threshold.toStringAsFixed(0)}%',
//                 activeColor: AppColor.accentGreen,
//                 onChanged: (value) {
//                   setState(() {
//                     _threshold = value;
//                   });
//                 },
//               ),
//               const SizedBox(height: Insets.md),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text('Enable Alerts', style: ResponsiveText.body(context)),
//                   Switch(
//                     value: _alertEnabled,
//                     onChanged: (value) {
//                       setState(() {
//                         _alertEnabled = value;
//                       });
//                     },
//                     activeColor: AppColor.accentGreen,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             if (_formKey.currentState!.validate()) {
//               final budget = double.parse(_budgetController.text);
//               widget.onSave(budget, _threshold, _alertEnabled);
//             }
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: AppColor.accentGreen,
//             foregroundColor: Colors.white,
//           ),
//           child: const Text('Save'),
//         ),
//       ],
//     );
//   }
// }
