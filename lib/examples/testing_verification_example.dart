import 'package:flutter/material.dart';
import '../services/testing_verification_service.dart';
import '../services/auth_service.dart';

/// Example demonstrating how to use the testing verification system
class TestingVerificationExample extends StatefulWidget {
  const TestingVerificationExample({super.key});

  @override
  State<TestingVerificationExample> createState() =>
      _TestingVerificationExampleState();
}

class _TestingVerificationExampleState
    extends State<TestingVerificationExample> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Verification Example'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Testing Mode Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Testing Mode Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<bool>(
                      future: TestingVerificationService.isTestingModeEnabled(),
                      builder: (context, snapshot) {
                        final isEnabled = snapshot.data ?? false;
                        return Row(
                          children: [
                            Icon(
                              isEnabled ? Icons.check_circle : Icons.cancel,
                              color: isEnabled ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEnabled
                                  ? 'Testing Mode Enabled'
                                  : 'Testing Mode Disabled',
                              style: TextStyle(
                                color: isEnabled ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Testing Codes List
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Testing Codes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...TestingVerificationService.getTestingScenarios().map((
                      scenario,
                    ) {
                      final code = TestingVerificationService.getTestingCode(
                        scenario,
                      );
                      final isSuccess = scenario == 'success';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isSuccess
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSuccess ? Colors.green : Colors.orange,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isSuccess ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$code - ${scenario.toUpperCase()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isSuccess
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _codeController.text = code;
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isSuccess ? Colors.green : Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                'USE',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Code Input and Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Verification Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-digit code',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 123456',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _testCode,
                          child: const Text('Test Code'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _toggleTestingMode,
                          child: const Text('Toggle Testing Mode'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Result Display
            if (_result.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Result',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_result, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _result = 'Please enter a code to test.';
      });
      return;
    }

    setState(() {
      _result = 'Testing code: $code...';
    });

    try {
      // Check if testing mode is enabled
      final isTestingMode =
          await TestingVerificationService.isTestingModeEnabled();

      if (isTestingMode) {
        // Test with testing service
        final result = TestingVerificationService.validateTestingCode(code);
        setState(() {
          _result =
              'Testing Mode Result:\n'
              'Code: $code\n'
              'Valid: ${result.isValid}\n'
              'Message: ${result.message}\n'
              'Scenario: ${result.scenario}';
        });
      } else {
        // Test with real auth service
        final isVerified = await _authService.verifyPhoneWithOTP(code);
        setState(() {
          _result =
              'Real Verification Result:\n'
              'Code: $code\n'
              'Verified: $isVerified';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error testing code: $e';
      });
    }
  }

  Future<void> _toggleTestingMode() async {
    final currentMode = await TestingVerificationService.isTestingModeEnabled();
    await TestingVerificationService.setTestingMode(!currentMode);

    setState(() {
      _result = 'Testing mode ${!currentMode ? 'enabled' : 'disabled'}.';
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}

/// Example function showing how to use the testing service programmatically
Future<void> exampleTestingUsage() async {
  // Enable testing mode
  await TestingVerificationService.setTestingMode(true);

  // Test different codes
  final codes = ['123456', '000000', '999999', '111111', '222222'];

  for (final code in codes) {
    final result = TestingVerificationService.validateTestingCode(code);
    print(
      'Code: $code - Valid: ${result.isValid} - Message: ${result.message}',
    );
  }

  // Get testing instructions
  final instructions = TestingVerificationService.getTestingInstructions();
  print('Instructions: $instructions');

  // Disable testing mode
  await TestingVerificationService.setTestingMode(false);
}





