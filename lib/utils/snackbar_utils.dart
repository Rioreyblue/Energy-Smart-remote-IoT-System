import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/constant.dart';

/// Enhanced SnackBar helper utilities for consistent feedback across the app

/// Show a success SnackBar with green theme and checkmark icon
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
          SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColor.accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 3),
    ),
  );
}

/// Show an error SnackBar with red theme and error icon
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Iconsax.close_circle, color: Colors.white, size: 20),
          SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColor.accentRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 3),
    ),
  );
}

/// Show a warning SnackBar with amber theme and warning icon
void showWarningSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Iconsax.warning_2, color: Colors.white, size: 20),
          SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColor.mediumConsumption,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 3),
    ),
  );
}

/// Show an info SnackBar with blue theme and info icon
void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Iconsax.info_circle, color: Colors.white, size: 20),
          SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColor.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 3),
    ),
  );
}
