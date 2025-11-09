class ValidationUtils {
  // Email validation
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Mobile number validation (Philippines format)
  static bool isValidMobileNumber(String mobileNumber) {
    // Remove any non-digit characters
    final cleanNumber = mobileNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it's a valid Philippine mobile number (09XXXXXXXXX)
    if (!RegExp(r'^09\d{9}$').hasMatch(cleanNumber)) {
      return false;
    }

    // Check for repeating numbers (e.g., 1111111111)
    if (_hasRepeatingNumbers(cleanNumber)) {
      return false;
    }

    return true;
  }

  // Check for repeating numbers in mobile number
  static bool _hasRepeatingNumbers(String number) {
    if (number.length < 4) return false;

    // Check for 4 or more consecutive same digits
    for (int i = 0; i <= number.length - 4; i++) {
      String substring = number.substring(i, i + 4);
      if (substring == substring[0] * 4) {
        return true;
      }
    }
    return false;
  }

  // Strong password validation
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must contain at least one special character';
    }

    return null; // Valid password
  }

  // Name validation
  static String? validateName(String name, String fieldName) {
    if (name.isEmpty) {
      return '$fieldName is required';
    }

    if (name.length < 2) {
      return '$fieldName must be at least 2 characters long';
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      return '$fieldName can only contain letters and spaces';
    }

    return null; // Valid name
  }

  // Address validation
  static String? validateAddress(String address) {
    if (address.isEmpty) {
      return 'Address is required';
    }

    if (address.length < 5) {
      return 'Address must be at least 5 characters long';
    }

    return null; // Valid address
  }

  // Energy provider validation
  static String? validateEnergyProvider(String provider) {
    if (provider.isEmpty) {
      return 'Energy provider is required';
    }

    return null; // Valid provider
  }

  // OTP validation
  static String? validateOTP(String otp) {
    if (otp.isEmpty) {
      return 'OTP is required';
    }

    if (otp.length != 6) {
      return 'OTP must be 6 digits';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return 'OTP must contain only numbers';
    }

    return null; // Valid OTP
  }

  // Check if verification attempts are exceeded (limit set to 7)
  static bool isVerificationAttemptsExceeded(int attempts) {
    return attempts >= 7;
  }

  // Check if enough time has passed for resend (30 seconds)
  static bool canResendVerification(DateTime? lastAttempt) {
    if (lastAttempt == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastAttempt);
    return difference.inSeconds >= 30;
  }

  // Get remaining cooldown time in seconds
  static int getRemainingCooldownSeconds(DateTime? lastAttempt) {
    if (lastAttempt == null) return 0;

    final now = DateTime.now();
    final difference = now.difference(lastAttempt);
    final remaining = 30 - difference.inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
