import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Firestore paths
  static const String _usersCollection = 'users';
  static const String _profileDoc = 'profile';

  // Realtime Database paths
  static const String _usersPath = 'users';

  // Save Firestore user profile (structured, analytics friendly)
  Future<void> saveUserProfile(String uid, Map<String, dynamic> profile) async {
    await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_profileDoc)
        .doc('main')
        .set(profile, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc =
        await _firestore
            .collection(_usersCollection)
            .doc(uid)
            .collection(_profileDoc)
            .doc('main')
            .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // Query by email using collectionGroup on profile
  Future<bool> isEmailInUse(String email) async {
    final snap =
        await _firestore
            .collectionGroup(_profileDoc)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
    return snap.docs.isNotEmpty;
  }

  // Save Realtime user (live fields)
  Future<void> saveRealtimeUser(String uid, Map<String, dynamic> user) async {
    await _database.ref('$_usersPath/$uid').set(user);
  }

  Future<void> updateRealtimeUser(String uid, Map<String, dynamic> user) async {
    await _database.ref('$_usersPath/$uid').update(user);
  }

  Future<Map<String, dynamic>?> getRealtimeUser(String uid) async {
    final snap = await _database.ref('$_usersPath/$uid').get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<bool> isMobileInUse(String mobileNumber) async {
    final snap =
        await _database
            .ref(_usersPath)
            .orderByChild('mobileNumber')
            .equalTo(mobileNumber)
            .limitToFirst(1)
            .get();
    return snap.exists;
  }

  // Update main Firestore user document (UserModel)
  Future<void> updateMainUserDocument(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    await _firestore.collection(_usersCollection).doc(uid).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update user fields in Realtime Database
  Future<void> updateRealtimeUserFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    await _database.ref('$_usersPath/$uid').update({
      ...updates,
      'updatedAt': ServerValue.timestamp,
    });
  }
}
