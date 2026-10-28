import 'package:flutter/material.dart';

/// A rich, metallic shimmering text widget designed for brand highlights like 'msm.movin 2022'
class MsmShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final List<Color>? colors;
  final Duration duration;

  const MsmShimmerText({
    super.key,
    this.text = 'ORG : msm.movin 2022',
    this.style,
    this.colors,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<MsmShimmerText> createState() => _MsmShimmerTextState();
}

class _MsmShimmerTextState extends State<MsmShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultColors = [
      const Color(0xFF818CF8), // Soft Indigo
      const Color(0xFFC7D2FE), // Lavender Light
      const Color(0xFFFFFFFF), // Pure White Glint
      const Color(0xFF38BDF8), // Sky Blue Accent
      const Color(0xFF818CF8), // Soft Indigo
    ];

    final colors = widget.colors ?? defaultColors;

    final baseStyle = widget.style ??
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Colors.white,
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final double slide = _controller.value;
            return LinearGradient(
              colors: colors,
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              begin: const Alignment(-2.0, 0.0),
              end: const Alignment(2.0, 0.0),
              transform: _TextSlidingGradientTransform(slidePercent: slide),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: baseStyle.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

class _TextSlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _TextSlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Smooth translation across bounds width
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 3.0 - 1.5),
      0.0,
      0.0,
    );
  }
}
