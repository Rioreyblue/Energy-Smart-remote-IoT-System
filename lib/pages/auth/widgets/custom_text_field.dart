import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffix;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveText.label(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            prefixIcon: Icon(icon, color: AppColor.primary),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.disabled),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.accentGreen, width: 2),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
