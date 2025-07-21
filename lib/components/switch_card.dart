import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:exercise_app/constants/constant.dart';
import 'dart:async';

class SwitchCard extends StatefulWidget {
  final String name;
  final IconData icon;
  final bool isOn;
  final String label;
  final String cost;
  final String timerText;
  final ValueChanged<bool> onToggle;
  const SwitchCard({
    required this.name,
    required this.icon,
    required this.isOn,
    required this.label,
    required this.cost,
    required this.timerText,
    required this.onToggle,
    super.key,
  });
  @override
  State<SwitchCard> createState() => _SwitchCardState();
}

class _SwitchCardState extends State<SwitchCard> {
  Timer? _timer;
  DateTime? _onStart;
  String _timerText = '0:00:00:00';
  bool _lastIsOn = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _lastIsOn = widget.isOn;
    if (widget.isOn) {
      _onStart = DateTime.now();
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant SwitchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn != _lastIsOn) {
      if (widget.isOn) {
        _onStart = DateTime.now();
        _startTimer();
      } else {
        _timer?.cancel();
        setState(() {
          _timerText = '0:00:00:00';
        });
      }
      _lastIsOn = widget.isOn;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_onStart != null && widget.isOn) {
        final diff = DateTime.now().difference(_onStart!);
        setState(() {
          _timerText = _formatDuration(diff);
        });
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        widget.isOn
            ? colorScheme.surfaceContainerHighest.withAlpha(
              (isDark ? 0.3 : 0.7) * 255 ~/ 1,
            )
            : colorScheme.surface;
    final borderColor =
        widget.isOn
            ? colorScheme.secondary
            : colorScheme.onSurface.withAlpha((0.2 * 255).toInt());
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).toInt()),
              blurRadius: _isPressed ? 2 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  widget.icon,
                  color:
                      widget.isOn
                          ? colorScheme.secondary
                          : colorScheme.onSurface,
                  size: 24,
                ),
                Container(
                  decoration: BoxDecoration(
                    color:
                        widget.isOn
                            ? colorScheme.secondary.withAlpha(
                              (0.15 * 255).toInt(),
                            )
                            : colorScheme.surfaceContainerHighest.withAlpha(
                              (0.1 * 255).toInt(),
                            ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CupertinoSwitch(
                    value: widget.isOn,
                    onChanged: widget.onToggle,
                    activeTrackColor: colorScheme.secondary,
                    inactiveTrackColor: colorScheme.onSurface.withAlpha(
                      (0.1 * 255).toInt(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Insets.sm),
            Text(
              widget.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Row(
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  widget.cost,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
            // Move duration text below cost
            SizedBox(height: Insets.xm),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: colorScheme.secondary),
                SizedBox(width: 4),
                Text(
                  _timerText,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
