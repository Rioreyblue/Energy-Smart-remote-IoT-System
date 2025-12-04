import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing per-user appliance display name overrides (aliases).
///
/// These aliases are stored in Firestore under:
///   users/{uid}/appliance_aliases/{applianceId}
///
/// This does NOT change the Realtime Database structure used by the ESP32.
class ApplianceAliasService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _aliasesCollection {
    final uid = _userId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('appliance_aliases');
  }

  /// Get all aliases for current user as a map: applianceId -> alias.
  Future<Map<String, String>> getAliases() async {
    final uid = _userId;
    if (uid == null) {
      return {};
    }

    final snapshot = await _aliasesCollection.get();
    if (snapshot.docs.isEmpty) return {};

    final Map<String, String> aliases = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final alias = (data['alias'] ?? '').toString().trim();
      if (alias.isNotEmpty) {
        aliases[doc.id] = alias;
      }
    }
    return aliases;
  }

  /// Set / update alias for a given appliance.
  Future<void> setAlias(String applianceId, String alias) async {
    final uid = _userId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final trimmed = alias.trim();
    if (trimmed.isEmpty) {
      // Empty alias means clear it
      await clearAlias(applianceId);
      return;
    }

    await _aliasesCollection.doc(applianceId).set({
      'alias': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Clear alias for a given appliance (revert to default name).
  Future<void> clearAlias(String applianceId) async {
    final uid = _userId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    await _aliasesCollection.doc(applianceId).delete();
  }
}
