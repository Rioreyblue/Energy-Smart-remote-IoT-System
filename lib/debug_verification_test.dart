import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';

/// Debug test class to verify the authentication and verification system
class VerificationTestPage extends StatefulWidget {
  const VerificationTestPage({super.key});

  @override
  State<VerificationTestPage> createState() => _VerificationTestPageState();
}

class _VerificationTestPageState extends State<VerificationTestPage> {
  final AuthService _authService = AuthService();
  String _status = 'Ready to test';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification System Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Status: $_status',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test Buttons
            ElevatedButton(
              onPressed: _isLoading ? null : _testCurrentUser,
              child: const Text('Check Current User'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testEmailVerification,
              child: const Text('Test Email Verification'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testPhoneVerification,
              child: const Text('Test Phone Verification'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testFullVerification,
              child: const Text('Test Full Verification Status'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testSendEmailVerification,
              child: const Text('Send Email Verification'),
            ),
            
            const SizedBox(height: 20),
            
            // Loading Indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testCurrentUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking current user...';
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final userData = await _authService.getCurrentUserData();
        setState(() {
          _status = 'User: ${user.email}\n'
              'Email Verified: ${user.emailVerified}\n'
              'Phone Verified: ${userData?.isPhoneVerified ?? false}\n'
              'UID: ${user.uid}';
        });
      } else {
        setState(() {
          _status = 'No user logged in';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testEmailVerification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing email verification...';
    });

    try {
      final isVerified = await _authService.isEmailVerified();
      setState(() {
        _status = 'Email verification status: $isVerified';
      });
    } catch (e) {
      setState(() {
        _status = 'Email verification error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPhoneVerification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing phone verification...';
    });

    try {
      final isVerified = await _authService.isPhoneVerified();
      setState(() {
        _status = 'Phone verification status: $isVerified';
      });
    } catch (e) {
      setState(() {
        _status = 'Phone verification error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFullVerification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing full verification status...';
    });

    try {
      final isFullyVerified = await _authService.isUserFullyVerified();
      setState(() {
        _status = 'Full verification status: $isFullyVerified';
      });
    } catch (e) {
      setState(() {
        _status = 'Full verification error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSendEmailVerification() async {
    setState(() {
      _isLoading = true;
      _status = 'Sending email verification...';
    });

    try {
      await _authService.sendEmailVerification();
      setState(() {
        _status = 'Email verification sent successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to send email verification: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

/// Test registration with email
Future<void> testEmailRegistration() async {
  final authService = AuthService();
  
  try {
    print('🧪 Testing email registration...');
    
    final user = await authService.registerUserWithEmail(
      email: 'test@example.com',
      password: 'TestPassword123!',
      firstName: 'Test',
      lastName: 'User',
      middleName: 'Middle',
      mobileNumber: '09123456789',
      energyProvider: 'Meralco',
      address: '123 Test Street, Test City',
    );
    
    if (user != null) {
      print('✅ Email registration successful: ${user.email}');
      print('📧 Email verification should be sent automatically');
    } else {
      print('❌ Email registration failed');
    }
  } catch (e) {
    print('❌ Email registration error: $e');
  }
}

/// Test registration with phone
Future<void> testPhoneRegistration() async {
  final authService = AuthService();
  
  try {
    print('🧪 Testing phone registration...');
    
    final verificationId = await authService.registerUserWithPhone(
      phoneNumber: '09123456789',
      firstName: 'Test',
      lastName: 'User',
      middleName: 'Middle',
      email: 'test@example.com',
      energyProvider: 'Meralco',
      address: '123 Test Street, Test City',
    );
    
    if (verificationId != null) {
      print('✅ Phone registration initiated: $verificationId');
      print('📱 SMS should be sent to the phone number');
    } else {
      print('❌ Phone registration failed');
    }
  } catch (e) {
    print('❌ Phone registration error: $e');
  }
}

/// Test verification flow
Future<void> testVerificationFlow() async {
  final authService = AuthService();
  
  try {
    print('🧪 Testing verification flow...');
    
    // Check current verification status
    final emailVerified = await authService.isEmailVerified();
    final phoneVerified = await authService.isPhoneVerified();
    final fullyVerified = await authService.isUserFullyVerified();
    
    print('📧 Email verified: $emailVerified');
    print('📱 Phone verified: $phoneVerified');
    print('✅ Fully verified: $fullyVerified');
    
    if (!emailVerified) {
      print('📧 Sending email verification...');
      await authService.sendEmailVerification();
    }
    
  } catch (e) {
    print('❌ Verification flow error: $e');
  }
}
