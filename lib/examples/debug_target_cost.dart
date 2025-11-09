import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../controllers/energy_dashboard_controller.dart';

/// Simple debug widget to test target cost functionality
class DebugTargetCost extends StatefulWidget {
  const DebugTargetCost({super.key});

  @override
  State<DebugTargetCost> createState() => _DebugTargetCostState();
}

class _DebugTargetCostState extends State<DebugTargetCost> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late EnergyDashboardController _controller;
  String _debugInfo = 'Initializing...';

  String get _userId => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _controller = EnergyDashboardController();
    _controller.addListener(() {
      setState(() {
        _debugInfo = 'Controller updated - Target Cost: ${_controller.targetCost}';
      });
    });
    _controller.initialize();
    _runDebugTest();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runDebugTest() async {
    if (_userId.isEmpty) {
      setState(() {
        _debugInfo = '❌ No authenticated user found';
      });
      return;
    }

    setState(() {
      _debugInfo = '🔍 Running debug test...';
    });

    try {
      // Test 1: Check database path
      final ref = _database.ref('users/$_userId/target_threshold');
      final snapshot = await ref.get();
      
      String info = 'Debug Test Results:\n\n';
      info += '1. User ID: $_userId\n';
      info += '2. Database Path: users/$_userId/target_threshold\n';
      info += '3. Snapshot exists: ${snapshot.exists}\n';
      info += '4. Snapshot value: ${snapshot.value}\n';
      
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        info += '5. Value type: ${value.runtimeType}\n';
        
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          info += '6. Map keys: ${map.keys.toList()}\n';
          info += '7. energy_threshold: ${map['energy_threshold']}\n';
          info += '8. target_cost: ${map['target_cost']}\n';
        }
      } else {
        info += '5. No data found at this path\n';
      }
      
      info += '\n9. Controller targetCost: ${_controller.targetCost}\n';
      info += '10. Controller formatted: ${_controller.getFormattedTargetCost()}\n';
      
      setState(() {
        _debugInfo = info;
      });
    } catch (e) {
      setState(() {
        _debugInfo = '❌ Error during debug test: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Target Cost'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Information:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _debugInfo,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _runDebugTest,
              child: const Text('🔄 Run Debug Test'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _controller.refresh,
              child: const Text('🔄 Refresh Controller'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('1. Check the debug information above'),
            const Text('2. Verify the database path and data structure'),
            const Text('3. Check if the controller is receiving the data'),
            const Text('4. Look for any error messages in the console'),
          ],
        ),
      ),
    );
  }
}
