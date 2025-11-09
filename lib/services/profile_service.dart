import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Service for managing user profile data in Firebase Realtime Database
class ProfileService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  StreamSubscription<DatabaseEvent>? _profileSubscription;

  // Profile data
  String _fullName = '';
  String _email = '';
  String _phoneNumber = '';
  String _address = '';
  String _profilePhotoUrl = '';
  bool _isLoading = true;
  String? _error;

  // Getters
  String get fullName => _fullName;
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get address => _address;
  String get profilePhotoUrl => _profilePhotoUrl;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfilePhoto => _profilePhotoUrl.isNotEmpty;

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Initialize the service and start listening to profile changes
  void initialize() {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _profileSubscription = _database
        .ref('users/$_userId')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value as Map<dynamic, dynamic>;

              // Debug logging: Log raw data received
              AppLogger.d('ProfileService: Raw data from database: $data');

              // Handle fullName: Check for fullName, otherwise construct from firstName + middleName + lastName
              if (data['fullName'] != null &&
                  (data['fullName'] as String).isNotEmpty) {
                _fullName = data['fullName'] as String;
              } else {
                final firstName = data['firstName']?.toString() ?? '';
                final middleName = data['middleName']?.toString() ?? '';
                final lastName = data['lastName']?.toString() ?? '';
                _fullName =
                    [
                      firstName,
                      middleName,
                      lastName,
                    ].where((name) => name.isNotEmpty).join(' ').trim();
                AppLogger.d(
                  'ProfileService: Constructed fullName from firstName/lastName: $_fullName',
                );
              }

              // Handle email
              _email = data['email']?.toString() ?? '';

              // Handle phoneNumber: Check for phoneNumber, otherwise use mobileNumber
              _phoneNumber =
                  data['phoneNumber']?.toString() ??
                  data['mobileNumber']?.toString() ??
                  '';
              if (data['phoneNumber'] == null && data['mobileNumber'] != null) {
                AppLogger.d(
                  'ProfileService: Mapped mobileNumber to phoneNumber: $_phoneNumber',
                );
              }

              // Handle address
              _address = data['address']?.toString() ?? '';

              // Handle profilePhotoUrl: Check for both profilePhotoUrl and photoURL
              _profilePhotoUrl =
                  data['profilePhotoUrl']?.toString() ??
                  data['photoURL']?.toString() ??
                  '';

              // Fallback to Firebase Auth user's photoURL if database doesn't have it
              if (_profilePhotoUrl.isEmpty) {
                final user = _auth.currentUser;
                if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
                  _profilePhotoUrl = user.photoURL!;
                  AppLogger.d(
                    'ProfileService: Using Firebase Auth photoURL as fallback: $_profilePhotoUrl',
                  );
                  // Optionally save to database for future use
                  _saveProfilePhotoUrlToDatabase(_profilePhotoUrl);
                } else {
                  AppLogger.d(
                    'ProfileService: No profile photo URL found in database or Firebase Auth',
                  );
                }
              } else {
                AppLogger.d(
                  'ProfileService: Profile photo URL from database: $_profilePhotoUrl',
                );
              }

              // Debug logging: Log parsed values
              AppLogger.d(
                'ProfileService: Parsed values - fullName: $_fullName, email: $_email, phoneNumber: $_phoneNumber, profilePhotoUrl: ${_profilePhotoUrl.isNotEmpty ? "present" : "empty"}',
              );

              _error = null;
            } else {
              // Initialize with current user data
              AppLogger.d(
                'ProfileService: No data in database, initializing profile',
              );
              _initializeProfile();
            }
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            AppLogger.e('ProfileService: Error loading profile: $error');
            _error = 'Failed to load profile: ${error.toString()}';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Initialize profile with current user data
  Future<void> _initializeProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Construct fullName from displayName or use empty string
      final fullName = user.displayName ?? '';

      // Get profile photo URL from Auth user
      final photoUrl = user.photoURL ?? '';

      await _database.ref('users/$_userId').set({
        'fullName': fullName,
        'email': user.email ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'mobileNumber':
            user.phoneNumber ??
            '', // Also save as mobileNumber for compatibility
        'address': '',
        'profilePhotoUrl': photoUrl,
        'photoURL': photoUrl, // Also save as photoURL for compatibility
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      // Update local state
      _fullName = fullName;
      _email = user.email ?? '';
      _phoneNumber = user.phoneNumber ?? '';
      _profilePhotoUrl = photoUrl;

      AppLogger.d(
        'ProfileService: Initialized profile with Firebase Auth data',
      );
    }
  }

  /// Save profile photo URL to database (used as fallback)
  Future<void> _saveProfilePhotoUrlToDatabase(String photoUrl) async {
    if (_userId.isEmpty) return;

    try {
      await _database.ref('users/$_userId').update({
        'profilePhotoUrl': photoUrl,
        'photoURL': photoUrl, // Also save as photoURL for compatibility
        'updatedAt': ServerValue.timestamp,
      });
      AppLogger.d('ProfileService: Saved profile photo URL to database');
    } catch (e) {
      AppLogger.e('ProfileService: Failed to save profile photo URL: $e');
      // Don't throw, this is just a convenience update
    }
  }

  /// Update profile information
  Future<bool> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
  }) async {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{'updatedAt': ServerValue.timestamp};

      if (fullName != null) {
        updates['fullName'] = fullName;
        _fullName = fullName;
      }
      if (phoneNumber != null) {
        updates['phoneNumber'] = phoneNumber;
        _phoneNumber = phoneNumber;
      }
      if (address != null) {
        updates['address'] = address;
        _address = address;
      }

      await _database.ref('users/$_userId').update(updates);

      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Upload profile photo to Firebase Storage
  Future<bool> uploadProfilePhoto(File imageFile) async {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Create a reference to the file location
      final ref = _storage.ref().child('profile_photos/$_userId.jpg');

      // Upload the file
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update profile with new photo URL
      await _database.ref('users/$_userId').update({
        'profilePhotoUrl': downloadUrl,
        'updatedAt': ServerValue.timestamp,
      });

      _profilePhotoUrl = downloadUrl;
      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to upload profile photo: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete profile photo
  Future<bool> deleteProfilePhoto() async {
    if (_userId.isEmpty) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Delete from storage if URL exists
      if (_profilePhotoUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(_profilePhotoUrl);
          await ref.delete();
        } catch (e) {
          // Photo might not exist in storage, continue with database update
        }
      }

      // Update database
      await _database.ref('users/$_userId').update({
        'profilePhotoUrl': '',
        'updatedAt': ServerValue.timestamp,
      });

      _profilePhotoUrl = '';
      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete profile photo: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Validate profile data
  Map<String, String> validateProfile({
    required String fullName,
    required String phoneNumber,
    required String address,
  }) {
    final errors = <String, String>{};

    if (fullName.trim().isEmpty) {
      errors['fullName'] = 'Full name is required';
    } else if (fullName.trim().length < 2) {
      errors['fullName'] = 'Full name must be at least 2 characters';
    }

    if (phoneNumber.trim().isEmpty) {
      errors['phoneNumber'] = 'Phone number is required';
    } else if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phoneNumber.trim())) {
      errors['phoneNumber'] = 'Please enter a valid phone number';
    }

    if (address.trim().isEmpty) {
      errors['address'] = 'Address is required';
    } else if (address.trim().length < 5) {
      errors['address'] = 'Address must be at least 5 characters';
    }

    return errors;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh profile data
  Future<void> refresh() async {
    initialize();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}
