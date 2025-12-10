import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../utils/validation_utils.dart';
import 'database_service.dart';
import '../utils/app_logger.dart';
import 'phone_auth_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Store verification ID and resend token
  String? _verificationId;
  int? _resendToken;

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Check if there's a different user already signed in (from previous session)
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Clear old user's verification status
        await _clearVerificationStatus(currentUser.uid);
      }

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Get user data from Firestore
        final userData = await _getUserData(result.user!.uid);
        if (userData != null) {
          // Save login state
          await _saveLoginState(true);
          // Clear session OTP verification - require OTP on every login
          await _clearSessionOtpVerification(result.user!.uid);
          return userData;
        }
      }
      return null;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Register new user with email and password
  Future<UserModel?> registerUserWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String middleName,
    required String mobileNumber,
    required String energyProvider,
    required String address,
  }) async {
    try {
      // Validate inputs
      _validateRegistrationInputs(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        mobileNumber: mobileNumber,
        address: address,
      );

      // Check unique constraints
      await _validateUniqueConstraints(
        email,
        mobileNumber,
        firstName,
        lastName,
        middleName,
      );

      // Create Firebase Auth user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create user model
        final userModel = UserModel(
          uid: result.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          middleName: middleName,
          mobileNumber: mobileNumber,
          energyProvider: energyProvider,
          address: address,
          createdAt: DateTime.now(),
          isApproved: false,
        );

        // Save organized data
        await _saveUserDataOrganized(userModel);

        // Send email verification (non-blocking - don't fail registration if this fails)
        try {
          await sendEmailVerification();
        } catch (emailError) {
          // Log the error but don't fail registration
          AppLogger.e(
            '[AuthService] ⚠️ Failed to send email verification, but registration succeeded: $emailError',
          );
          // User can resend verification email later from the verification page
        }

        return userModel;
      }
      return null;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Send phone verification OTP via SmsChef (post-registration flow).
  Future<void> sendPhoneVerificationOtp(String phoneNumber) async {
    try {
      final phoneAuthService = PhoneAuthService();
      final sent = await phoneAuthService.verifyPhoneNumber(phoneNumber);

      if (!sent) {
        final error =
            phoneAuthService.error ??
            'Failed to send verification code. Please try again.';
        throw Exception(error);
      }

      // Ensure legacy Firebase identifiers are cleared when using SmsChef.
      _verificationId = null;
      _resendToken = null;
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error sending phone OTP: $e');
      throw _handleAuthError(e);
    }
  }

  @Deprecated(
    'Phone-only registration has been removed. Use registerUserWithEmail '
    'followed by sendPhoneVerificationOtp instead.',
  )
  Future<String?> registerUserWithPhone({
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String middleName,
    required String email,
    required String energyProvider,
    required String address,
  }) async {
    AppLogger.w(
      '[AuthService] ⚠️ registerUserWithPhone is deprecated. This call only '
      'triggers SmsChef OTP delivery for existing accounts.',
    );
    await sendPhoneVerificationOtp(phoneNumber);
    return null;
  }

  // Validate registration inputs
  void _validateRegistrationInputs({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String address,
  }) {
    if (!ValidationUtils.isValidEmail(email)) {
      throw Exception('Please enter a valid email address');
    }

    final passwordError = ValidationUtils.validatePassword(password);
    if (passwordError != null) {
      throw Exception(passwordError);
    }

    final firstNameError = ValidationUtils.validateName(
      firstName,
      'First name',
    );
    if (firstNameError != null) {
      throw Exception(firstNameError);
    }

    final lastNameError = ValidationUtils.validateName(lastName, 'Last name');
    if (lastNameError != null) {
      throw Exception(lastNameError);
    }

    if (!ValidationUtils.isValidMobileNumber(mobileNumber)) {
      throw Exception('Please enter a valid mobile number (09XXXXXXXXX)');
    }

    final addressError = ValidationUtils.validateAddress(address);
    if (addressError != null) {
      throw Exception(addressError);
    }
  }

  // Validate unique constraints
  Future<void> _validateUniqueConstraints(
    String email,
    String mobileNumber,
    String firstName,
    String lastName,
    String middleName,
  ) async {
    // Check email uniqueness
    final isEmailRegistered = await this.isEmailRegistered(email);
    if (isEmailRegistered) {
      throw Exception('An account with this email address already exists.');
    }

    // Check mobile number uniqueness
    final isMobileRegistered = await this.isMobileNumberRegistered(
      mobileNumber,
    );
    if (isMobileRegistered) {
      throw Exception('An account with this mobile number already exists.');
    }

    // Check full name + address uniqueness
    final isNameRegistered = await this.isFullNameRegistered(
      firstName,
      lastName,
      middleName,
    );
    if (isNameRegistered) {
      throw Exception('An account with this name combination already exists.');
    }
  }

  // Save user data (Firestore profile + RTDB live data)
  Future<void> _saveUserDataOrganized(UserModel userModel) async {
    try {
      // Firestore profile (no live fields)
      await _db.saveUserProfile(userModel.uid, {
        'uid': userModel.uid,
        'email': userModel.email,
        'firstName': userModel.firstName,
        'lastName': userModel.lastName,
        'verificationMethod': userModel.isPhoneVerified ? 'phone' : 'email',
        'energyProvider': userModel.energyProvider,
        'address': userModel.address,
        'createdAt': userModel.createdAt.toIso8601String(),
        'role': 'user',
      });

      // Realtime Database user (live + identity fields)
      await _db.saveRealtimeUser(userModel.uid, {
        'uid': userModel.uid,
        'email': userModel.email,
        'firstName': userModel.firstName,
        'lastName': userModel.lastName,
        'middleName': userModel.middleName,
        'mobileNumber': userModel.mobileNumber,
        'verificationMethod': userModel.isPhoneVerified ? 'phone' : 'email',
        'energyProvider': userModel.energyProvider,
        'address': userModel.address,
        'createdAt': userModel.createdAt.toIso8601String(),
        'isApproved': userModel.isApproved,
        'isEmailVerified': userModel.isEmailVerified,
        'isPhoneVerified': userModel.isPhoneVerified,
        'verificationAttempts': userModel.verificationAttempts,
        'lastVerificationAttempt':
            userModel.lastVerificationAttempt?.toIso8601String(),
        'status': 'active',
      });
    } catch (e) {
      throw Exception('Failed to save user data: ${e.toString()}');
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user found. Please log in again.');
      }

      if (user.emailVerified) {
        AppLogger.i(
          '[AuthService] ✅ Email already verified for: ${user.email}',
        );
        return;
      }

      AppLogger.d(
        '[AuthService] 📧 Sending email verification to: ${user.email}',
      );

      // Send email verification without ActionCodeSettings
      // Firebase will use the default email template configured in Firebase Console
      await user.sendEmailVerification();

      AppLogger.i(
        '[AuthService] ✅ Email verification sent successfully to: ${user.email}',
      );
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error sending email verification: $e');
      AppLogger.e(
        '[AuthService] Error details: ${e.runtimeType} - ${e.toString()}',
      );

      // Provide more helpful error message
      String errorMessage = 'Failed to send verification email.';
      if (e.toString().contains('network')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage =
            'Too many requests. Please wait a few minutes before requesting another email.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage =
            'Invalid email address. Please check your email and try again.';
      }

      throw Exception('$errorMessage ${e.toString()}');
    }
  }

  // Check if email is verified (checks SharedPreferences first)
  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check SharedPreferences first
      final prefsVerified = await _getVerificationStatusFromPrefs(
        user.uid,
        'email',
      );
      if (prefsVerified != null && prefsVerified) {
        AppLogger.d('[AuthService] Email verified from SharedPreferences');
        return true;
      }

      // Fallback to Firebase check
      await user.reload();
      final isVerified = user.emailVerified;

      // Save to SharedPreferences if verified
      if (isVerified) {
        await _saveVerificationStatus(user.uid, 'email', true);
      }

      return isVerified;
    } catch (e) {
      AppLogger.e('[AuthService] Error checking email verification: $e');
      return false;
    }
  }

  // Verify email by checking Firebase's email verification status
  Future<bool> verifyEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user found. Please log in again.');
      }

      AppLogger.d(
        '[AuthService] 🔍 Checking email verification status for: ${user.email}',
      );
      await user.reload();

      if (user.emailVerified) {
        AppLogger.i(
          '[AuthService] ✅ Email verified successfully for: ${user.email}',
        );
        // Update user data to mark email as verified
        await _updateUserVerificationStatus(user.uid, isEmailVerified: true);
        // Save to SharedPreferences for persistence
        await _saveVerificationStatus(user.uid, 'email', true);
        return true;
      }

      AppLogger.e('[AuthService] ❌ Email not yet verified for: ${user.email}');
      return false;
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error in verifyEmail: $e');
      throw _handleAuthError(e);
    }
  }

  // Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      return await _db.isEmailInUse(email);
    } catch (e) {
      return false;
    }
  }

  // Check if mobile number is already registered
  Future<bool> isMobileNumberRegistered(String mobileNumber) async {
    try {
      return await _db.isMobileInUse(mobileNumber);
    } catch (e) {
      return false;
    }
  }

  // Check if full name combination is already registered
  Future<bool> isFullNameRegistered(
    String firstName,
    String lastName,
    String middleName,
  ) async {
    // Skip cross-db full name uniqueness to reduce coupling and reads
    return false;
  }

  // Get user data from Firestore
  Future<UserModel?> _getUserData(String uid) async {
    try {
      // Get Firestore profile
      final profile = await _db.getUserProfile(uid);
      if (profile == null) {
        AppLogger.w('[AuthService] Profile is null for uid: $uid');
        return null;
      }

      // Get RTDB live user (optional)
      final live = await _db.getRealtimeUser(uid) ?? {};

      // Debug: Log mobile number sources (support both keys: mobileNumber/phoneNumber)
      final mobileFromLive =
          (live['mobileNumber'] ?? live['phoneNumber']) as String?;
      final mobileFromProfile =
          (profile['mobileNumber'] ?? profile['phoneNumber']) as String?;
      final finalMobile = mobileFromLive ?? mobileFromProfile ?? '';

      if (finalMobile.isEmpty) {
        AppLogger.w(
          '[AuthService] Mobile number not found in either source. '
          'Live: ${mobileFromLive ?? "null"}, Profile: ${mobileFromProfile ?? "null"}',
        );
      } else {
        AppLogger.d(
          '[AuthService] Mobile number found: ${_maskPhoneNumber(finalMobile)}',
        );
      }

      return UserModel(
        uid: uid,
        email: (profile['email'] ?? live['email'] ?? '') as String,
        firstName: (profile['firstName'] ?? live['firstName'] ?? '') as String,
        lastName: (profile['lastName'] ?? live['lastName'] ?? '') as String,
        middleName:
            (live['middleName'] ?? profile['middleName'] ?? '') as String,
        mobileNumber: finalMobile,
        energyProvider:
            (profile['energyProvider'] ?? live['energyProvider'] ?? '')
                as String,
        address: (profile['address'] ?? live['address'] ?? '') as String,
        createdAt:
            DateTime.tryParse(
              (profile['createdAt'] ?? live['createdAt'] ?? '') as String,
            ) ??
            DateTime.now(),
        isApproved: (live['isApproved'] ?? false) as bool,
        isEmailVerified: (live['isEmailVerified'] ?? false) as bool,
        isPhoneVerified: (live['isPhoneVerified'] ?? false) as bool,
        verificationAttempts: (live['verificationAttempts'] ?? 0) as int,
        lastVerificationAttempt:
            (live['lastVerificationAttempt'] != null)
                ? DateTime.tryParse(live['lastVerificationAttempt'] as String)
                : null,
        adminNotes: live['adminNotes'] as String?,
      );
    } catch (e) {
      AppLogger.e('[AuthService] Error in _getUserData: $e');
      return null;
    }
  }

  // Get current user data
  Future<UserModel?> getCurrentUserData() async {
    if (currentUser != null) {
      return await _getUserData(currentUser!.uid);
    }
    return null;
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      AppLogger.d('[AuthService] 🔐 Starting Google sign-in process');

      // Initialize Google Sign In with server client ID for idToken
      // This is the Web client ID from Firebase Console
      final googleSignIn = GoogleSignIn(
        serverClientId:
            '281073543283-f9prvi1q4251jl8qpjjv7v38lnnqf3t6.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      // Check if there's a different user already signed in
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Clear old user's verification status
        await _clearVerificationStatus(currentUser.uid);
      }

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        AppLogger.d('[AuthService] User cancelled Google sign-in');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      if (result.user != null) {
        AppLogger.i(
          '[AuthService] ✅ Google sign-in successful for user: ${result.user!.uid}',
        );

        // Check if user already exists in Firestore
        var userData = await _getUserData(result.user!.uid);

        if (userData == null) {
          // New user - create user data from Google account
          final displayName = result.user!.displayName ?? '';
          final nameParts = displayName.split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts.first : '';
          final lastName = nameParts.length > 1 ? nameParts.last : '';

          userData = UserModel(
            uid: result.user!.uid,
            email: result.user!.email ?? '',
            firstName: firstName,
            lastName: lastName,
            middleName: '',
            mobileNumber: '',
            energyProvider: '',
            address: '',
            createdAt: DateTime.now(),
            isApproved: false,
            isEmailVerified: result.user!.emailVerified,
            isPhoneVerified: false,
          );

          // Save user data to Firestore and Realtime Database
          await _saveUserDataOrganized(userData);
          AppLogger.i(
            '[AuthService] ✅ Created new user profile from Google account',
          );
        } else {
          // Existing user - update email verification status if needed
          if (result.user!.emailVerified && !userData.isEmailVerified) {
            userData = userData.copyWith(isEmailVerified: true);
            await _saveUserDataOrganized(userData);
          }
        }

        // Save login state
        await _saveLoginState(true);
        // Clear session OTP verification - require OTP on every login
        await _clearSessionOtpVerification(result.user!.uid);

        return userData;
      }

      return null;
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error in signInWithGoogle: $e');

      // Provide more specific error messages for common issues
      if (e.toString().contains('network_error') ||
          e.toString().contains('ApiException: 7')) {
        AppLogger.e(
          '[AuthService] Google Sign-In Network Error. '
          'This usually means:\n'
          '1. SHA-1/SHA-256 fingerprints are missing in Firebase Console\n'
          '2. Google Play Services is not available or outdated\n'
          '3. Network connectivity issues\n'
          'To fix: Get your SHA-1 fingerprint using:\n'
          '  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android\n'
          'Then add it to Firebase Console > Project Settings > Your App > SHA certificate fingerprints',
        );
        throw Exception(
          'Google Sign-In failed: Network error. Please ensure:\n'
          '1. SHA-1/SHA-256 fingerprints are added in Firebase Console\n'
          '2. Google Play Services is updated\n'
          '3. You have internet connection',
        );
      }

      throw _handleAuthError(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      final uid = user?.uid;

      // Sign out Firebase
      await _auth.signOut();
      // Sign out Google if previously signed in
      try {
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (_) {}

      // Clear verification status from SharedPreferences
      if (uid != null) {
        await _clearVerificationStatus(uid);
        await _clearSessionOtpVerification(uid);
      }

      await _saveLoginState(false);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Save login state to SharedPreferences
  Future<void> _saveLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  // Get login state from SharedPreferences
  Future<bool> getLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Save verification status to SharedPreferences
  Future<void> _saveVerificationStatus(
    String uid,
    String type,
    bool isVerified,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${type}_verified_$uid';
      await prefs.setBool(key, isVerified);
      AppLogger.d(
        '[AuthService] Saved $type verification status to SharedPreferences: $isVerified',
      );
    } catch (e) {
      AppLogger.e(
        '[AuthService] Error saving verification status to SharedPreferences: $e',
      );
    }
  }

  // Get verification status from SharedPreferences
  Future<bool?> _getVerificationStatusFromPrefs(String uid, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${type}_verified_$uid';
      return prefs.getBool(key);
    } catch (e) {
      AppLogger.e(
        '[AuthService] Error reading verification status from SharedPreferences: $e',
      );
      return null;
    }
  }

  // Clear verification status from SharedPreferences
  Future<void> _clearVerificationStatus(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('email_verified_$uid');
      await prefs.remove('phone_verified_$uid');
      AppLogger.d(
        '[AuthService] Cleared verification status from SharedPreferences for user: $uid',
      );
    } catch (e) {
      AppLogger.e(
        '[AuthService] Error clearing verification status from SharedPreferences: $e',
      );
    }
  }

  // Handle authentication errors
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      AppLogger.e(
        '[AuthService] 🔥 Firebase Auth Error: ${error.code} - ${error.message}',
      );
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'email-already-in-use':
          return 'An account already exists with this email address.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'invalid-verification-code':
          return 'Invalid verification code. Please try again.';
        case 'invalid-verification-id':
          return 'Verification session expired. Please try again.';
        case 'credential-already-in-use':
          return 'This phone number is already registered.';
        case 'phone-number-already-exists':
          return 'This phone number is already registered.';
        case 'quota-exceeded':
          return 'SMS quota exceeded. Please try again later.';
        case 'app-not-authorized':
          return 'App not authorized for phone authentication.';
        default:
          return 'Authentication failed: ${error.message}';
      }
    }
    AppLogger.e('[AuthService] 🔥 General Error: $error');
    return 'An unexpected error occurred. Please try again.';
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Change user password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Reauthenticate with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      AppLogger.i('[AuthService] Password changed successfully');
      return true;
    } catch (e) {
      AppLogger.e('[AuthService] Error changing password: $e');
      throw _handleAuthError(e);
    }
  }

  // Verify phone with OTP via SmsChef / PhoneAuthService
  Future<bool> verifyPhoneWithOTP(String otp) async {
    try {
      // Legacy: registration flow still uses Firebase phone auth
      if (_verificationId != null) {
        AppLogger.d(
          '[AuthService] 🔐 Verifying phone with legacy Firebase flow',
        );

        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );

        final result = await _auth.signInWithCredential(credential);

        if (result.user != null) {
          AppLogger.i(
            '[AuthService] ✅ Phone verification successful for user: ${result.user!.uid}',
          );
          await _updateUserVerificationStatus(
            result.user!.uid,
            isPhoneVerified: true,
          );
          await _saveVerificationStatus(result.user!.uid, 'phone', true);
          // Mark session OTP as verified for this login session
          await _setSessionOtpVerified(result.user!.uid);
          return true;
        }

        return false;
      }

      // Default: use SmsChef + PhoneAuthService session
      final phoneAuthService = PhoneAuthService();
      final isVerified = await phoneAuthService.verifyOTP(otp);

      if (!isVerified) {
        final errorMessage =
            phoneAuthService.error ??
            'Invalid verification code. Please try again.';
        throw Exception(errorMessage);
      }

      final user = _auth.currentUser;
      if (user != null) {
        await _saveVerificationStatus(user.uid, 'phone', true);
        // Mark session OTP as verified for this login session
        await _setSessionOtpVerified(user.uid);
      }

      AppLogger.i('[AuthService] ✅ Phone verification completed via SmsChef');
      return true;
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error in verifyPhoneWithOTP: $e');
      throw _handleAuthError(e);
    }
  }

  // Update user verification status
  Future<void> _updateUserVerificationStatus(
    String uid, {
    bool? isEmailVerified,
    bool? isPhoneVerified,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (isEmailVerified != null) {
        updateData['isEmailVerified'] = isEmailVerified;
        // Also save to SharedPreferences
        await _saveVerificationStatus(uid, 'email', isEmailVerified);
      }
      if (isPhoneVerified != null) {
        updateData['isPhoneVerified'] = isPhoneVerified;
        // Also save to SharedPreferences
        await _saveVerificationStatus(uid, 'phone', isPhoneVerified);
      }
      // Update RTDB only for live verification state
      await _db.updateRealtimeUser(uid, updateData);
      AppLogger.i('[AuthService] ✅ Updated verification status for user: $uid');
    } catch (e) {
      throw Exception('Failed to update verification status: ${e.toString()}');
    }
  }

  // Resend verification code
  Future<void> resendVerificationCode({
    String? phoneNumber,
    required String verificationType,
  }) async {
    try {
      AppLogger.d(
        '[AuthService] 🔄 Resending $verificationType verification...',
      );

      if (verificationType == 'phone') {
        // Get phone number from parameter or current user data
        String? phoneToUse = phoneNumber;

        if (phoneToUse == null || phoneToUse.trim().isEmpty) {
          AppLogger.d(
            '[AuthService] Phone number not provided, attempting to retrieve from user data...',
          );
          final user = _auth.currentUser;
          if (user != null) {
            final userData = await _getUserData(user.uid);
            if (userData == null) {
              AppLogger.e(
                '[AuthService] User data is null for uid: ${user.uid}',
              );
              throw Exception('User data not found. Please log in again.');
            }
            phoneToUse = userData.mobileNumber;
            AppLogger.d(
              '[AuthService] Retrieved phone number from user data: ${phoneToUse.isNotEmpty ? 'Found: ${_maskPhoneNumber(phoneToUse)}' : 'Empty string'}',
            );
          } else {
            AppLogger.e('[AuthService] No current user found');
            throw Exception('No user found. Please log in again.');
          }
        }

        if (phoneToUse.trim().isEmpty) {
          throw Exception(
            'Phone number not found. Please provide a valid phone number.',
          );
        }

        // If verificationId is still present we are likely in the legacy
        // registration flow, so use Firebase phone auth again.
        if (_verificationId != null) {
          final formattedPhone = _formatPhoneNumber(phoneToUse);
          AppLogger.d(
            '[AuthService] Using formatted phone number for legacy resend: ${_maskPhoneNumber(formattedPhone)}',
          );

          await _auth.verifyPhoneNumber(
            phoneNumber: formattedPhone,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (PhoneAuthCredential credential) async {
              AppLogger.i(
                '[AuthService] ✅ Auto verification completed during legacy resend',
              );
            },
            verificationFailed: (FirebaseAuthException e) {
              AppLogger.i(
                '❌ Phone verification failed during legacy resend: ${e.code} - ${e.message}',
              );
              throw _handleAuthError(e);
            },
            codeSent: (String verificationId, int? resendToken) {
              AppLogger.i(
                '[AuthService] ✅ SMS code resent (legacy)! Verification ID: $verificationId',
              );
              _verificationId = verificationId;
              _resendToken = resendToken;
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              AppLogger.w(
                '[AuthService] ⏱️ Auto retrieval timeout during legacy resend: $verificationId',
              );
              _verificationId = verificationId;
            },
            forceResendingToken: _resendToken,
          );
        } else {
          final phoneAuthService = PhoneAuthService();
          final otpSent = await phoneAuthService.verifyPhoneNumber(phoneToUse);

          if (!otpSent) {
            final errorMessage =
                phoneAuthService.error ??
                'Failed to send verification code. Please try again.';
            throw Exception(errorMessage);
          }
        }
      } else if (verificationType == 'email') {
        final user = _auth.currentUser;
        if (user != null) {
          AppLogger.i(
            '[AuthService] 📧 Resending email verification to: ${user.email}',
          );
          await user.sendEmailVerification();
          AppLogger.i('[AuthService] ✅ Email verification resent successfully');
        } else {
          throw Exception('No user found. Please log in again.');
        }
      }
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error resending verification: $e');
      throw _handleAuthError(e);
    }
  }

  // Safely format phone number to E.164. Defaults to PH +63 rules.
  String _formatPhoneNumber(String input) {
    if (input.trim().isEmpty) {
      throw Exception(
        'Invalid phone number: Cannot format an empty phone number.',
      );
    }

    String cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) {
      throw Exception('Invalid phone number: No digits found in "$input".');
    }

    if (cleaned.startsWith('+')) {
      // Already in international format, validate it has enough digits
      if (cleaned.length < 12) {
        throw Exception(
          'Invalid phone number: International format requires at least 12 characters (e.g., +639123456789).',
        );
      }
      return cleaned;
    }

    if (cleaned.startsWith('0')) {
      // Local PH number like 09xxxxxxxxx -> +639xxxxxxxxx
      if (cleaned.length < 11) {
        throw Exception(
          'Invalid phone number: Philippine local format requires 11 digits (e.g., 09123456789).',
        );
      }
      return '+63${cleaned.substring(1)}';
    }

    if (cleaned.startsWith('63')) {
      // Already has country code but missing +
      if (cleaned.length < 12) {
        throw Exception(
          'Invalid phone number: Philippine format with country code requires 12 digits (e.g., 639123456789).',
        );
      }
      return '+$cleaned';
    }

    // Fallback: assume already country code-less local, prefix +63
    if (cleaned.length < 10) {
      throw Exception(
        'Invalid phone number: Phone number too short. Expected at least 10 digits.',
      );
    }
    return '+63$cleaned';
  }

  // Mask phone number for secure logging (shows only last 4 digits)
  String _maskPhoneNumber(String phoneNumber) {
    if (phoneNumber.length <= 4) return '****';
    final lastFour = phoneNumber.substring(phoneNumber.length - 4);
    final masked = '*' * (phoneNumber.length - 4);
    return '$masked$lastFour';
  }

  /// Check if phone is verified (checks SharedPreferences first)
  Future<bool> isPhoneVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check SharedPreferences first
      final prefsVerified = await _getVerificationStatusFromPrefs(
        user.uid,
        'phone',
      );
      if (prefsVerified != null && prefsVerified) {
        AppLogger.d('[AuthService] Phone verified from SharedPreferences');
        return true;
      }

      // Fallback to database check
      final userData = await _getUserData(user.uid);
      final isVerified = userData?.isPhoneVerified ?? false;

      // Save to SharedPreferences if verified
      if (isVerified) {
        await _saveVerificationStatus(user.uid, 'phone', true);
      }

      return isVerified;
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error checking phone verification: $e');
      return false;
    }
  }

  /// Check if user is fully verified (both email and phone)
  Future<bool> isUserFullyVerified() async {
    try {
      final emailVerified = await isEmailVerified();
      final phoneVerified = await isPhoneVerified();
      return emailVerified && phoneVerified;
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error checking full verification: $e');
      return false;
    }
  }

  /// Check if session OTP is verified (required on every login)
  Future<bool> isSessionOtpVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final key = 'session_otp_verified_${user.uid}';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      AppLogger.e(
        '[AuthService] ❌ Error checking session OTP verification: $e',
      );
      return false;
    }
  }

  /// Set session OTP as verified (after successful OTP verification)
  Future<void> _setSessionOtpVerified(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'session_otp_verified_$uid';
      await prefs.setBool(key, true);
      AppLogger.d('[AuthService] Session OTP verified for user: $uid');
    } catch (e) {
      AppLogger.e('[AuthService] Error setting session OTP verified: $e');
    }
  }

  /// Clear session OTP verification (required on every login)
  Future<void> _clearSessionOtpVerification(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'session_otp_verified_$uid';
      await prefs.setBool(key, false);
      AppLogger.d(
        '[AuthService] Session OTP verification cleared for user: $uid',
      );
    } catch (e) {
      AppLogger.e('[AuthService] Error clearing session OTP verification: $e');
    }
  }

  // Check if user can resend verification
  Future<bool> canResendVerification(String uid) async {
    try {
      final userData = await _getUserData(uid);
      if (userData == null) return false;

      return ValidationUtils.canResendVerification(
        userData.lastVerificationAttempt,
      );
    } catch (e) {
      return false;
    }
  }

  // Get remaining cooldown time
  Future<int> getRemainingCooldownTime(String uid) async {
    try {
      final userData = await _getUserData(uid);
      if (userData == null) return 0;

      return ValidationUtils.getRemainingCooldownSeconds(
        userData.lastVerificationAttempt,
      );
    } catch (e) {
      return 0;
    }
  }

  // Update verification attempts with automatic reset after 2 minutes
  Future<void> updateVerificationAttempts(String uid) async {
    try {
      final userData = await _getUserData(uid);
      if (userData == null) return;

      final now = DateTime.now();
      int newAttempts = 1;

      // Check if last verification attempt was more than 2 minutes ago
      if (userData.lastVerificationAttempt != null) {
        final timeSinceLastAttempt = now.difference(
          userData.lastVerificationAttempt!,
        );

        // Reset attempts if 2 minutes (120 seconds) have passed
        if (timeSinceLastAttempt.inSeconds >= 120) {
          newAttempts = 1;
          AppLogger.i(
            '[AuthService] Verification attempts reset after 2 minutes',
          );
        } else {
          // Increment attempts if within 2 minutes
          newAttempts = userData.verificationAttempts + 1;
        }
      }

      // Update RTDB only
      await _db.updateRealtimeUser(uid, {
        'verificationAttempts': newAttempts,
        'lastVerificationAttempt': now.toIso8601String(),
      });

      AppLogger.d('[AuthService] Verification attempts updated: $newAttempts');
    } catch (e) {
      AppLogger.e('[AuthService] Failed to update verification attempts: $e');
      throw Exception(
        'Failed to update verification attempts: ${e.toString()}',
      );
    }
  }

  // Check if verification attempts exceeded
  Future<bool> isVerificationAttemptsExceeded(String uid) async {
    try {
      final userData = await _getUserData(uid);
      if (userData == null) return false;

      return ValidationUtils.isVerificationAttemptsExceeded(
        userData.verificationAttempts,
      );
    } catch (e) {
      return false;
    }
  }
}
