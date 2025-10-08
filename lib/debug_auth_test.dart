import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> testAuthFlow() async {
  try {
    print('🔥 Testing Authentication Flow...\n');

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    // Test Firebase Auth
    final auth = FirebaseAuth.instance;
    print('✅ Firebase Auth instance created');

    // Test Firestore
    final firestore = FirebaseFirestore.instance;
    print('✅ Firestore instance created');

    // Check current user
    final currentUser = auth.currentUser;
    print('👤 Current user: ${currentUser?.uid ?? "No user logged in"}');

    // Test auth state stream
    auth.authStateChanges().listen((User? user) {
      if (user != null) {
        print('✅ User is authenticated: ${user.uid}');
        print('📧 Email: ${user.email}');
        print('📱 Phone: ${user.phoneNumber ?? "No phone"}');
        print('✅ Email verified: ${user.emailVerified}');
      } else {
        print('❌ No user authenticated');
      }
    });

    print('\n🎉 Authentication flow test completed!');
    print('\n📝 Next steps:');
    print('1. Make sure Firebase is properly configured');
    print('2. Test login with valid credentials');
    print('3. Check if navigation to HomeScreen works');
  } catch (e) {
    print('❌ Authentication flow test failed: $e');
    print('\n🔧 Please check:');
    print('1. Firebase configuration in firebase_options.dart');
    print('2. Firebase project setup');
    print('3. Authentication methods enabled in Firebase Console');
  }
}

void main() async {
  await testAuthFlow();
}



