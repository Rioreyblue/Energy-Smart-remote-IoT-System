import 'package:flutter/material.dart';

/// A widget that smoothly animates numeric value changes
class AnimatedNumberWidget extends StatefulWidget {
  final double value;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int? fractionDigits;
  final String Function(double)? formatter;

  const AnimatedNumberWidget({
    super.key,
    required this.value,
    this.prefix,
    this.suffix,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.fractionDigits,
    this.formatter,
  });

  @override
  State<AnimatedNumberWidget> createState() => _AnimatedNumberWidgetState();
}

class _AnimatedNumberWidgetState extends State<AnimatedNumberWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(AnimatedNumberWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller.forward(from: 0.0);
      _previousValue = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    if (widget.formatter != null) {
      return widget.formatter!(value);
    }

    if (widget.fractionDigits != null) {
      return value.toStringAsFixed(widget.fractionDigits!);
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayValue = _formatValue(_animation.value);
        return Text(
          '${widget.prefix ?? ''}$displayValue${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

/// A specialized widget for currency values with smooth transitions
class AnimatedCurrencyWidget extends StatelessWidget {
  final double value;
  final String currency;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int fractionDigits;

  const AnimatedCurrencyWidget({
    super.key,
    required this.value,
    this.currency = '₱',
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.fractionDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedNumberWidget(
      value: value,
      prefix: currency,
      style: style,
      duration: duration,
      curve: curve,
      fractionDigits: fractionDigits,
    );
  }
}

/// A specialized widget for kWh values with smooth transitions
class AnimatedKwhWidget extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int fractionDigits;

  const AnimatedKwhWidget({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.fractionDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedNumberWidget(
      value: value,
      suffix: ' kWh',
      style: style,
      duration: duration,
      curve: curve,
      fractionDigits: fractionDigits,
    );
  }
}

/// A widget that provides smooth transitions for percentage values
class AnimatedPercentageWidget extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int fractionDigits;

  const AnimatedPercentageWidget({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.fractionDigits = 1,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedNumberWidget(
      value: value,
      suffix: '%',
      style: style,
      duration: duration,
      curve: curve,
      fractionDigits: fractionDigits,
    );
  }
}


