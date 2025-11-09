import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String middleName;
  final String mobileNumber;
  final String energyProvider;
  final String address;
  final DateTime createdAt;
  final bool isApproved;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final int verificationAttempts;
  final DateTime? lastVerificationAttempt;
  final String? adminNotes;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.mobileNumber,
    required this.energyProvider,
    required this.address,
    required this.createdAt,
    this.isApproved = false,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.verificationAttempts = 0,
    this.lastVerificationAttempt,
    this.adminNotes,
  });

  // Getter for full name
  String get fullName =>
      '$firstName ${middleName.isNotEmpty ? '$middleName ' : ''}$lastName';

  // Getter for display name
  String get displayName => '$firstName $lastName';

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'mobileNumber': mobileNumber,
      'energyProvider': energyProvider,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'isApproved': isApproved,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'verificationAttempts': verificationAttempts,
      'lastVerificationAttempt':
          lastVerificationAttempt != null
              ? Timestamp.fromDate(lastVerificationAttempt!)
              : null,
      'adminNotes': adminNotes,
    };
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'mobileNumber': mobileNumber,
      'energyProvider': energyProvider,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'isApproved': isApproved,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'verificationAttempts': verificationAttempts,
      'lastVerificationAttempt':
          lastVerificationAttempt != null
              ? Timestamp.fromDate(lastVerificationAttempt!)
              : null,
      'adminNotes': adminNotes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create from Map (from Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      middleName: map['middleName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      energyProvider: map['energyProvider'] ?? '',
      address: map['address'] ?? '',
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      isApproved: map['isApproved'] ?? false,
      isEmailVerified: map['isEmailVerified'] ?? false,
      isPhoneVerified: map['isPhoneVerified'] ?? false,
      verificationAttempts: map['verificationAttempts'] ?? 0,
      lastVerificationAttempt:
          map['lastVerificationAttempt'] != null
              ? DateTime.parse(map['lastVerificationAttempt'])
              : null,
      adminNotes: map['adminNotes'],
    );
  }

  // Create from Firestore document
  factory UserModel.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      middleName: data['middleName'] ?? '',
      mobileNumber: data['mobileNumber'] ?? '',
      energyProvider: data['energyProvider'] ?? '',
      address: data['address'] ?? '',
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      isApproved: data['isApproved'] ?? false,
      isEmailVerified: data['isEmailVerified'] ?? false,
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      verificationAttempts: data['verificationAttempts'] ?? 0,
      lastVerificationAttempt:
          data['lastVerificationAttempt'] != null
              ? (data['lastVerificationAttempt'] as Timestamp).toDate()
              : null,
      adminNotes: data['adminNotes'],
    );
  }

  // Copy with method for updates
  UserModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? middleName,
    String? mobileNumber,
    String? energyProvider,
    String? address,
    DateTime? createdAt,
    bool? isApproved,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    int? verificationAttempts,
    DateTime? lastVerificationAttempt,
    String? adminNotes,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      energyProvider: energyProvider ?? this.energyProvider,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      isApproved: isApproved ?? this.isApproved,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      verificationAttempts: verificationAttempts ?? this.verificationAttempts,
      lastVerificationAttempt:
          lastVerificationAttempt ?? this.lastVerificationAttempt,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }
}
