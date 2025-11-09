import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminAnalyticsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _activeUsers = 0;
  double _totalEnergyKwh = 0.0;
  double _totalCost = 0.0;
  double _currentPowerRate = 0.0;
  List<Map<String, dynamic>> _recentUpdates = const [];
  bool _loading = true;
  String? _error;

  int get activeUsers => _activeUsers;
  double get totalEnergyKwh => _totalEnergyKwh;
  double get totalCost => _totalCost;
  double get currentPowerRate => _currentPowerRate;
  List<Map<String, dynamic>> get recentUpdates => _recentUpdates;
  bool get loading => _loading;
  String? get error => _error;

  StreamSubscription? _usersSub;
  StreamSubscription? _energySub;
  StreamSubscription? _costSub;
  StreamSubscription? _rateSub;
  StreamSubscription? _updatesSub;

  void initialize() {
    _loading = true;
    _listenActiveUsers();
    _listenTotalEnergy();
    _listenTotalCost();
    _listenPowerRate();
    _listenRecentUpdates();
  }

  void _listenActiveUsers() {
    _usersSub?.cancel();
    _usersSub = _firestore
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen(
          (snap) {
            _activeUsers = snap.size;
            _finishOne();
          },
          onError: (e) {
            _error = e.toString();
            _finishOne();
          },
        );
  }

  void _listenTotalEnergy() {
    _energySub?.cancel();
    // Sum of latest totals from energy_data/{uid} docs (expects field totalKwh)
    _energySub = _firestore
        .collection('energy_data')
        .snapshots()
        .listen(
          (snap) {
            double sum = 0.0;
            for (final d in snap.docs) {
              final v = d.data()['totalKwh'];
              if (v is num) sum += v.toDouble();
            }
            _totalEnergyKwh = sum;
            _finishOne();
          },
          onError: (e) {
            _error = e.toString();
            _finishOne();
          },
        );
  }

  void _listenTotalCost() {
    _costSub?.cancel();
    _costSub = _firestore
        .collection('users')
        .snapshots()
        .listen(
          (snap) {
            double sum = 0.0;
            for (final doc in snap.docs) {
              final data = doc.data();
              // Check todayUsage for totalCost
              final todayUsage = data['todayUsage'];
              if (todayUsage is Map && todayUsage['totalCost'] is num) {
                sum += (todayUsage['totalCost'] as num).toDouble();
              }
            }
            _totalCost = sum;
            _finishOne();
          },
          onError: (e) {
            _error = e.toString();
            _finishOne();
          },
        );
  }

  void _listenPowerRate() {
    _rateSub?.cancel();
    _rateSub = _firestore
        .collection('admin_settings')
        .doc('system_config')
        .snapshots()
        .listen(
          (doc) {
            final data = doc.data();
            if (data != null && data['powerRate'] is num) {
              _currentPowerRate = (data['powerRate'] as num).toDouble();
            }
            _finishOne();
          },
          onError: (e) {
            _error = e.toString();
            _finishOne();
          },
        );
  }

  void _listenRecentUpdates() {
    _updatesSub?.cancel();
    // Recent activity from all users - collect from recent_activity subcollections
    _updatesSub = _firestore
        .collectionGroup('recent_activity')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen(
          (snap) {
            _recentUpdates =
                snap.docs.map((d) {
                  final m = d.data();
                  return {
                    'id': d.id,
                    'type': m['type'] ?? 'unknown',
                    'message': m['message'] ?? 'No message',
                    'timestamp': m['timestamp'],
                    'userId': m['userId'] ?? 'unknown',
                  };
                }).toList();
            _finishOne();
          },
          onError: (e) {
            _error = e.toString();
            _finishOne();
          },
        );
  }

  void _finishOne() {
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _energySub?.cancel();
    _costSub?.cancel();
    _rateSub?.cancel();
    _updatesSub?.cancel();
    super.dispose();
  }
}
