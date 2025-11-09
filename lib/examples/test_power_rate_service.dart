import 'package:flutter/material.dart';
import 'package:exercise_app/services/power_rate_service.dart';

class TestPowerRateService extends StatefulWidget {
  const TestPowerRateService({super.key});

  @override
  State<TestPowerRateService> createState() => _TestPowerRateServiceState();
}

class _TestPowerRateServiceState extends State<TestPowerRateService> {
  final PowerRateService _powerRateService = PowerRateService();
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _status = 'Loading power rate...';
    });

    try {
      await _powerRateService.initialize();
      setState(() {
        _status = 'Power rate loaded successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Rate Service Test'),
        backgroundColor: Colors.green,
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
                    const Text(
                      'Power Rate Service Test',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Status: $_status'),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: _powerRateService,
                      builder: (context, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Rate: ₱${_powerRateService.currentRate.toStringAsFixed(2)}',
                            ),
                            Text('Is Loading: ${_powerRateService.isLoading}'),
                            if (_powerRateService.error != null)
                              Text('Error: ${_powerRateService.error}'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _initializeService,
                  child: const Text('🔄 Refresh'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    final success = await _powerRateService.setPowerRate(15.75);
                    setState(() {
                      _status =
                          success
                              ? 'Rate updated to ₱15.75'
                              : 'Failed to update rate';
                    });
                  },
                  child: const Text('💰 Set Test Rate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected Firestore Structure:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Collection: admin_settings'),
                    Text('Document: system_config'),
                    Text('Field: powerRate (number)'),
                    SizedBox(height: 8),
                    Text(
                      'Example:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('powerRate: 12.50'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



