import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../utils/validation_utils.dart';
import 'database_service.dart';
import 'testing_verification_service.dart';
import '../utils/app_logger.dart';

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

        // Send email verification
        await sendEmailVerification();

        return userModel;
      }
      return null;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Register new user with phone number
  Future<String?> registerUserWithPhone({
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String middleName,
    required String email,
    required String energyProvider,
    required String address,
  }) async {
    try {
      // Validate inputs
      _validatePhoneRegistrationInputs(
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
        email: email,
        address: address,
      );

      // Check unique constraints
      await _validateUniqueConstraints(
        email,
        phoneNumber,
        firstName,
        lastName,
        middleName,
      );

      // Send OTP to phone number
      await _auth.verifyPhoneNumber(
        phoneNumber: _formatPhoneNumber(phoneNumber),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          AppLogger.i(
            '[AuthServiceFixed] ✅ Auto verification completed for phone: $phoneNumber',
          );
          await _completePhoneRegistration(
            credential: credential,
            firstName: firstName,
            lastName: lastName,
            middleName: middleName,
            email: email,
            phoneNumber: phoneNumber,
            energyProvider: energyProvider,
            address: address,
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.e(
            '[AuthServiceFixed] ❌ Phone verification failed: ${e.code} - ${e.message}',
          );
          throw _handleAuthError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          AppLogger.i(
            '[AuthServiceFixed] ✅ SMS code sent! Verification ID: $verificationId',
          );
          _verificationId = verificationId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          AppLogger.w(
            '[AuthServiceFixed] ⏱️ Auto retrieval timeout: $verificationId',
          );
          _verificationId = verificationId;
        },
      );

      return _verificationId;
    } catch (e) {
      AppLogger.e('[AuthServiceFixed] ❌ Error in registerUserWithPhone: $e');
      throw _handleAuthError(e);
    }
  }

  // Complete phone registration after OTP verification
  Future<UserModel?> completePhoneRegistration({
    required String otp,
    required String firstName,
    required String lastName,
    required String middleName,
    required String email,
    required String phoneNumber,
    required String energyProvider,
    required String address,
  }) async {
    try {
      if (_verificationId == null) {
        throw Exception('Verification ID not found. Please try again.');
      }

      AppLogger.d(
        '[AuthServiceFixed] 🔐 Attempting phone verification with OTP: $otp',
      );

      // Create credential with OTP
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      return await _completePhoneRegistration(
        credential: credential,
        firstName: firstName,
        lastName: lastName,
        middleName: middleName,
        email: email,
        phoneNumber: phoneNumber,
        energyProvider: energyProvider,
        address: address,
      );
    } catch (e) {
      AppLogger.e(
        '[AuthServiceFixed] ❌ Error in completePhoneRegistration: $e',
      );
      throw _handleAuthError(e);
    }
  }

  // Safely format phone number to E.164 (PH +63 default)
  String _formatPhoneNumber(String input) {
    String cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) {
      throw Exception('Invalid phone number.');
    }
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('0')) {
      return '+63${cleaned.length > 1 ? cleaned.substring(1) : ''}';
    }
    if (cleaned.startsWith('63')) {
      return '+$cleaned';
    }
    return '+63$cleaned';
  }

  // Private method to complete phone registration
  Future<UserModel?> _completePhoneRegistration({
    required PhoneAuthCredential credential,
    required String firstName,
    required String lastName,
    required String middleName,
    required String email,
    required String phoneNumber,
    required String energyProvider,
    required String address,
  }) async {
    try {
      // Sign in with phone credential
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      if (result.user != null) {
        print(
          '✅ Phone authentication successful for user: ${result.user!.uid}',
        );

        // Create user model
        final userModel = UserModel(
          uid: result.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          middleName: middleName,
          mobileNumber: phoneNumber,
          energyProvider: energyProvider,
          address: address,
          createdAt: DateTime.now(),
          isApproved: false,
          isPhoneVerified: true,
        );

        // Save organized data
        await _saveUserDataOrganized(userModel);

        // Save login state
        await _saveLoginState(true);

        return userModel;
      }
      return null;
    } catch (e) {
      AppLogger.e(
        '[AuthServiceFixed] ❌ Error in _completePhoneRegistration: $e',
      );
      throw _handleAuthError(e);
    }
  }

  // PUBLIC METHODS FOR VERIFICATION

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user found. Please log in again.');
      }

      if (user.emailVerified) {
        AppLogger.i(
          '[AuthServiceFixed] ✅ Email already verified for: ${user.email}',
        );
        return;
      }

      await user.sendEmailVerification();
      AppLogger.i(
        '[AuthServiceFixed] ✅ Email verification sent to: ${user.email}',
      );
    } catch (e) {
      AppLogger.e('[AuthServiceFixed] ❌ Error sending email verification: $e');
      throw _handleAuthError(e);
    }
  }

  /// Verify email by checking Firebase's email verification status
  Future<bool> verifyEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user found. Please log in again.');
      }

      AppLogger.d(
        '[AuthServiceFixed] 🔍 Checking email verification status for: ${user.email}',
      );
      await user.reload();

      if (user.emailVerified) {
        AppLogger.i(
          '[AuthServiceFixed] ✅ Email verified successfully for: ${user.email}',
        );
        // Update user data to mark email as verified
        await _updateUserVerificationStatus(user.uid, isEmailVerified: true);
        return true;
      }

      AppLogger.e(
        '[AuthServiceFixed] ❌ Email not yet verified for: ${user.email}',
      );
      return false;
    } catch (e) {
      AppLogger.e('[AuthServiceFixed] ❌ Error in verifyEmail: $e');
      throw _handleAuthError(e);
    }
  }

  /// Verify phone with OTP (for existing users)
  Future<bool> verifyPhoneWithOTP(String otp) async {
    try {
      // Check if testing mode is enabled
      final isTestingMode =
          await TestingVerificationService.isTestingModeEnabled();

      if (isTestingMode) {
        AppLogger.i(
          '[AuthServiceFixed] 🧪 Testing mode enabled - validating testing code: $otp',
        );
        final testingResult = TestingVerificationService.validateTestingCode(
          otp,
        );

        if (testingResult.isValid) {
          AppLogger.i(
            '[AuthServiceFixed] ✅ Testing code accepted: ${testingResult.scenario}',
          );
          // Simulate successful verification for testing
          final user = _auth.currentUser;
          if (user != null) {
            await _updateUserVerificationStatus(
              user.uid,
              isPhoneVerified: true,
            );
          }
          return true;
        } else {
          AppLogger.e(
            '[AuthServiceFixed] ❌ Testing code rejected: ${testingResult.message}',
          );
          throw Exception(testingResult.message);
        }
      }

      // Real verification logic
      if (_verificationId == null) {
        throw Exception('Verification ID not found. Please try again.');
      }

      AppLogger.d('[AuthServiceFixed] 🔐 Verifying phone with OTP: $otp');

      // Create credential with OTP
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Sign in with phone credential
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      if (result.user != null) {
        AppLogger.i(
          '[AuthServiceFixed] ✅ Phone verification successful for user: ${result.user!.uid}',
        );
        // Update user data to mark phone as verified
        await _updateUserVerificationStatus(
          result.user!.uid,
          isPhoneVerified: true,
        );
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.e('[AuthServiceFixed] ❌ Error in verifyPhoneWithOTP: $e');
      throw _handleAuthError(e);
    }
  }

  /// Resend verification code (email or phone)
  Future<void> resendVerificationCode({
    required String phoneNumber,
    required String verificationType,
  }) async {
    try {
      AppLogger.d(
        '[AuthServiceFixed] 🔄 Resending $verificationType verification...',
      );

      // Check if testing mode is enabled
      final isTestingMode =
          await TestingVerificationService.isTestingModeEnabled();

      if (isTestingMode && verificationType == 'phone') {
        AppLogger.i(
          '[AuthServiceFixed] 🧪 Testing mode enabled - simulating SMS resend',
        );
        // Simulate successful resend in testing mode
        _verificationId = 'testing_verification_id';
        _resendToken = 12345;
        AppLogger.i(
          '[AuthServiceFixed] ✅ Testing SMS code "resent" successfully',
        );
        return;
      }

      if (verificationType == 'phone') {
        await _auth.verifyPhoneNumber(
          phoneNumber: '+63${phoneNumber.substring(1)}',
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            AppLogger.i(
              '[AuthServiceFixed] ✅ Auto verification completed during resend',
            );
          },
          verificationFailed: (FirebaseAuthException e) {
            print(
              '❌ Phone verification failed during resend: ${e.code} - ${e.message}',
            );
            throw _handleAuthError(e);
          },
          codeSent: (String verificationId, int? resendToken) {
            AppLogger.i(
              '[AuthServiceFixed] ✅ SMS code resent! Verification ID: $verificationId',
            );
            _verificationId = verificationId;
            _resendToken = resendToken;
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            AppLogger.w(
              '[AuthServiceFixed] ⏱️ Auto retrieval timeout during resend: $verificationId',
            );
            _verificationId = verificationId;
          },
          forceResendingToken: _resendToken,
        );
      } else if (verificationType == 'email') {
        final user = _auth.currentUser;
        if (user != null) {
          AppLogger.i(
            '[AuthServiceFixed] 📧 Resending email verification to: ${user.email}',
          );
          await user.sendEmailVerification();
          AppLogger.i(
            '[AuthServiceFixed] ✅ Email verification resent successfully',
          );
        } else {
          throw Exception('No user found. Please log in again.');
        }
      }
    } catch (e) {
      AppLogger.e('[AuthServiceFixed] ❌ Error resending verification: $e');
      throw _handleAuthError(e);
    }
  }

  /// Check if email is verified
  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.reload();
      return user.emailVerified;
    } catch (e) {
      AppLogger.e('[AuthServiceFixed] ❌ Error checking email verification: $e');
      return false;
    }
  }

  /// Check if phone is verified (from database)
  Future<bool> isPhoneVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userData = await _getUserData(user.uid);
      return userData?.isPhoneVerified ?? false;
    } catch (e) {
      AppLogger.e('[AuthServiceFixed] ❌ Error checking phone verification: $e');
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
      AppLogger.e('[AuthServiceFixed] ❌ Error checking full verification: $e');
      return false;
    }
  }

  // PRIVATE HELPER METHODS

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

  // Validate phone registration inputs
  void _validatePhoneRegistrationInputs({
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String email,
    required String address,
  }) {
    if (!ValidationUtils.isValidEmail(email)) {
      throw Exception('Please enter a valid email address');
    }

    if (!ValidationUtils.isValidMobileNumber(phoneNumber)) {
      throw Exception('Please enter a valid mobile number (09XXXXXXXXX)');
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
        'energyProvider': userModel.energyProvider,
        'address': userModel.address,
        'createdAt': userModel.createdAt.toIso8601String(),
        'isApproved': userModel.isApproved,
        'isEmailVerified': userModel.isEmailVerified,
        'isPhoneVerified': userModel.isPhoneVerified,
        'verificationAttempts': userModel.verificationAttempts,
        'lastVerificationAttempt':
            userModel.lastVerificationAttempt?.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to save user data: ${e.toString()}');
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
      if (profile == null) return null;

      // Get RTDB live user (optional)
      final live = await _db.getRealtimeUser(uid) ?? {};

      return UserModel(
        uid: uid,
        email: (profile['email'] ?? live['email'] ?? '') as String,
        firstName: (profile['firstName'] ?? live['firstName'] ?? '') as String,
        lastName: (profile['lastName'] ?? live['lastName'] ?? '') as String,
        middleName: (live['middleName'] ?? '') as String,
        mobileNumber: (live['mobileNumber'] ?? '') as String,
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

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      try {
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (_) {}
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
      }
      if (isPhoneVerified != null) {
        updateData['isPhoneVerified'] = isPhoneVerified;
      }
      // Update RTDB only for live verification state
      await _db.updateRealtimeUser(uid, updateData);
      AppLogger.i(
        '[AuthServiceFixed] ✅ Updated verification status for user: $uid',
      );
    } catch (e) {
      throw Exception('Failed to update verification status: ${e.toString()}');
    }
  }

  // Handle authentication errors
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      AppLogger.e(
        '[AuthServiceFixed] 🔥 Firebase Auth Error: ${error.code} - ${error.message}',
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
    AppLogger.e('[AuthServiceFixed] 🔥 General Error: $error');
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

      AppLogger.i('[AuthService] ✅ Password changed successfully');
      return true;
    } catch (e) {
      AppLogger.e('[AuthService] ❌ Error changing password: $e');
      throw _handleAuthError(e);
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
