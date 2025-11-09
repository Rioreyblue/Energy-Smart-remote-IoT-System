import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../controllers/energy_dashboard_controller.dart';

/// Simple test to debug target cost issue
class SimpleTargetTest extends StatefulWidget {
  const SimpleTargetTest({super.key});

  @override
  State<SimpleTargetTest> createState() => _SimpleTargetTestState();
}

class _SimpleTargetTestState extends State<SimpleTargetTest> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late EnergyDashboardController _controller;

  String _status = 'Initializing...';
  String? _dbValue;
  double _controllerValue = 0.0;

  String get _userId => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _controller = EnergyDashboardController();
    _controller.addListener(() {
      setState(() {
        _controllerValue = _controller.targetCost;
        _status = 'Controller updated: ${_controller.targetCost}';
      });
    });
    _controller.initialize();
    _testDatabase();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testDatabase() async {
    if (_userId.isEmpty) {
      setState(() {
        _status = '❌ No user logged in';
      });
      return;
    }

    setState(() {
      _status = '🔍 Testing database...';
    });

    try {
      // Test 1: Direct database read
      final ref = _database.ref('users/$_userId/target_threshold');
      final snapshot = await ref.get();

      setState(() {
        _dbValue = snapshot.exists ? snapshot.value.toString() : 'No data';
        _status = 'Database read complete';
      });

      // Test 2: Set a test value
      await ref.set({
        'energy_threshold': 2500.0,
        'target_cost': 2500.0,
        'alert_enabled': true,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        _status = '✅ Test value set: 2500.0';
      });

      // Test 3: Read it back
      await Future.delayed(const Duration(seconds: 2));
      final newSnapshot = await ref.get();
      setState(() {
        _dbValue =
            newSnapshot.exists ? newSnapshot.value.toString() : 'No data';
        _status = '✅ Value set and read back successfully';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Target Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_status'),
                    const SizedBox(height: 10),
                    Text('User ID: $_userId'),
                    Text('Database Value: $_dbValue'),
                    Text('Controller Value: $_controllerValue'),
                    Text(
                      'Controller Formatted: ${_controller.getFormattedTargetCost()}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testDatabase,
              child: const Text('🔄 Test Database'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _controller.refresh();
                setState(() {
                  _status = 'Controller refreshed';
                });
              },
              child: const Text('🔄 Refresh Controller'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final value = await _controller.getCurrentTargetCost();
                setState(() {
                  _controllerValue = value;
                  _status = 'Manual database check completed - Value: $value';
                });
              },
              child: const Text('🔍 Check Database'),
            ),
            const SizedBox(height: 20),
            const Text(
              'This test will:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text('1. Read current database value'),
            const Text('2. Set a test value (2500.0)'),
            const Text('3. Read it back to verify'),
            const Text('4. Show controller value'),
          ],
        ),
      ),
    );
  }
}
