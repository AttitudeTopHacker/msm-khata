import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Smooth Counting Animation for Dashboard Currency Values
/// Animates numbers from 0 up to their target value with an ease-out curve.
class AnimatedCurrencyText extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;
  final bool isPrivate;
  final String maskText;
  final int decimalDigits;

  const AnimatedCurrencyText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '₹',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1100),
    this.curve = Curves.easeOutCubic,
    this.isPrivate = false,
    this.maskText = '••••••',
    this.decimalDigits = 0,
  });

  @override
  State<AnimatedCurrencyText> createState() => _AnimatedCurrencyTextState();
}

class _AnimatedCurrencyTextState extends State<AnimatedCurrencyText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
    _controller.forward();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
      _controller.forward(from: 0.0);
      _previousValue = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPrivate) {
      return Text(
        widget.maskText,
        style: widget.style,
      );
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: widget.prefix,
      decimalDigits: widget.decimalDigits,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentVal = _animation.value;
        final isNegative = currentVal < 0;
        final formatted = currencyFormatter.format(currentVal.abs());
        return Text(
          '${isNegative ? '-' : ''}$formatted${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

