import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String role;
  final Timestamp createdAt;
  final Timestamp? lastSeen;
  final bool isOnline;

  ChatUserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.photoUrl,
    this.lastSeen,
    this.isOnline = false,
  });

  factory ChatUserProfile.fromMap(String id, Map<String, dynamic> data) {
    return ChatUserProfile(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()),
      lastSeen: data['lastSeen'] as Timestamp?,
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'lastSeen': lastSeen,
      'isOnline': isOnline,
    };
  }
}

