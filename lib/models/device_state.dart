import 'package:flutter/material.dart';
import 'dart:async';

class DeviceStateModel {
  final String name;
  final IconData icon;
  final String label;
  final String cost;
  bool isOn;
  DateTime? _onStart;
  String timerText = '0:00:00:00';
  Timer? _timer;

  DeviceStateModel({
    required this.name,
    required this.icon,
    required this.isOn,
    required this.label,
    required this.cost,
  }) {
    if (isOn) {
      _onStart = DateTime.now();
      _startTimer();
    }
  }

  void toggle(bool value) {
    if (value == isOn) return;
    isOn = value;
    if (isOn) {
      _onStart = DateTime.now();
      _startTimer();
    } else {
      _timer?.cancel();
      timerText = '0:00:00:00';
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_onStart != null) {
        final diff = DateTime.now().difference(_onStart!);
        timerText = _formatDuration(diff);
      }
    });
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return '$days:${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _timer?.cancel();
  }
}
