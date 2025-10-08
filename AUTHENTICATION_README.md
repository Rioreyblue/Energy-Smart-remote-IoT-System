# Firebase Authentication System for Energy Smart App

## Overview

This comprehensive Firebase Authentication system provides secure user registration and login with multiple authentication methods, robust validation, and modern UI components.

## Features Implemented

### ✅ Authentication Options
- **Email + Password Registration**: Traditional email/password signup with strong password validation
- **Phone Number Registration**: SMS OTP-based registration for mobile users
- **Email Verification**: Automatic email verification after registration
- **Phone Verification**: SMS OTP verification for phone registrations

### ✅ User Data Storage
- **Dual Database Storage**: Data stored in both Firestore and Realtime Database
- **Comprehensive User Model**: Includes all required fields:
  - Full name (first, middle, last)
  - Mobile number
  - Email address
  - User address/energy provider location
  - Registration timestamp
  - Verification status flags
  - Admin approval status

### ✅ Validation & Security
- **Strong Password Requirements**: 8+ chars, uppercase, lowercase, number, special character
- **Mobile Number Validation**: Philippine format (09XXXXXXXXX) with repeating number detection
- **Email Format Validation**: Proper email format verification
- **Duplicate Prevention**: No duplicate emails, mobile numbers, or name+address combinations
- **Input Validation**: All fields validated for non-empty and proper formats

### ✅ Verification Flow
- **Email Verification**: Send verification link/OTP after email registration
- **SMS OTP Verification**: Send 6-digit OTP for phone registrations
- **Attempt Limiting**: Maximum 3 verification attempts before temporary account lock
- **Cooldown System**: 30-second cooldown between resend attempts
- **Auto-redirect**: Automatic navigation to home page after successful verification

### ✅ User Experience
- **Modern UI Components**: Custom text fields, buttons, and verification inputs
- **Progress Indicators**: Loading states during registration and verification
- **Clear Error Messages**: Specific error messages for different failure scenarios
- **Responsive Design**: Works across different screen sizes
- **Theme Support**: Dark/light theme compatibility

### ✅ Security Features
- **Firebase Authentication**: Core auth handling through Firebase
- **Secure Data Storage**: Sensitive data properly hashed and stored
- **Database Security Rules**: Comprehensive Firestore and Realtime Database rules
- **Admin Controls**: Admin approval system for new registrations

## File Structure

```
lib/
├── models/
│   └── user_model.dart              # Enhanced user model with all required fields
├── services/
│   └── auth_service.dart            # Comprehensive authentication service
├── utils/
│   └── validation_utils.dart        # Validation utilities for all input types
├── pages/auth/
│   ├── login_page.dart              # Modern login page with email/password
│   ├── register_page.dart           # Registration with email/phone options
│   └── verification_page.dart       # OTP/email verification page
└── constants/
    └── constant.dart                # App constants and styling
```

## Database Security Rules

### Firestore Rules
- Users can only read/write their own data
- Admins can read all user data and update approval status
- Energy data is user-specific with admin read access
- Default deny all other documents

### Realtime Database Rules
- User-specific data access only
- Admin read access for management
- Secure data isolation between users

## Usage Examples

### Email Registration
```dart
final user = await _authService.registerUserWithEmail(
  email: 'user@example.com',
  password: 'SecurePass123!',
  firstName: 'John',
  lastName: 'Doe',
  middleName: 'Michael',
  mobileNumber: '09123456789',
  energyProvider: 'MOELCI Uno',
  address: '123 Main Street, City',
);
```

### Phone Registration
```dart
final verificationId = await _authService.registerUserWithPhone(
  phoneNumber: '09123456789',
  firstName: 'John',
  lastName: 'Doe',
  middleName: 'Michael',
  email: 'user@example.com',
  energyProvider: 'MOELCI Uno',
  address: '123 Main Street, City',
);
```

### Email Verification
```dart
final isVerified = await _authService.verifyEmailWithOTP('123456');
```

### Phone Verification
```dart
final isVerified = await _authService.verifyPhoneWithOTP('123456');
```

## Validation Examples

### Password Validation
```dart
final passwordError = ValidationUtils.validatePassword('password');
// Returns error message if password doesn't meet requirements
```

### Mobile Number Validation
```dart
final isValid = ValidationUtils.isValidMobileNumber('09123456789');
// Returns true for valid Philippine mobile numbers
```

### Email Validation
```dart
final isValid = ValidationUtils.isValidEmail('user@example.com');
// Returns true for valid email format
```

## Navigation Flow

1. **Login Page** → User enters credentials
2. **Registration Page** → User chooses email or phone registration
3. **Verification Page** → User verifies email/phone with OTP
4. **Home Page** → Successful authentication and verification

## Error Handling

The system provides comprehensive error handling with user-friendly messages:
- "Email already exists"
- "Mobile number already registered"
- "Password too weak"
- "Invalid verification code"
- "Too many verification attempts"

## Security Considerations

- All sensitive data is properly validated and sanitized
- Firebase Authentication handles secure credential management
- Database rules prevent unauthorized access
- Verification attempts are limited to prevent abuse
- Cooldown periods prevent spam

## Dependencies Added

```yaml
dependencies:
  firebase_auth: ^5.6.2
  cloud_firestore: ^5.6.11
  firebase_core: ^3.15.1
  firebase_database: ^11.0.4
  pin_code_fields: ^8.0.1
  shared_preferences: ^2.2.2
```

## Next Steps

1. **Configure Firebase Project**: Update `firebase_options.dart` with your actual Firebase configuration
2. **Test Authentication**: Test both email and phone registration flows
3. **Admin Panel**: Implement admin approval system for new registrations
4. **Email Templates**: Customize email verification templates
5. **SMS Integration**: Configure SMS provider for OTP delivery

## Support

For any issues or questions regarding the authentication system, please refer to the Firebase documentation or contact the development team.

