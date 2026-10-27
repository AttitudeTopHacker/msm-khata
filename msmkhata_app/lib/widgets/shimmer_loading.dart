import 'package:flutter/material.dart';

/// A self-contained, smooth, high-performance Shimmer Animation
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFF1E293B),
                Color(0xFF334155),
                Color(0xFF475569),
                Color(0xFF334155),
                Color(0xFF1E293B),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              begin: const Alignment(-1.5, -0.3),
              end: const Alignment(1.5, 0.3),
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Generic Shimmer Placeholder Box
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? (borderRadius ?? BorderRadius.circular(8)) : null,
      ),
    );
  }
}

/// Shimmer Skeleton for Net Position Card on Dashboard
class ShimmerNetPositionCard extends StatelessWidget {
  const ShimmerNetPositionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: double.infinity,
        height: 190,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF334155), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 140, height: 16),
                ShimmerBox(width: 90, height: 24, borderRadius: BorderRadius.all(Radius.circular(12))),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerBox(width: 200, height: 36),
            const Spacer(),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 110, height: 12),
                      SizedBox(height: 6),
                      ShimmerBox(width: 90, height: 16),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 100, height: 12),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 16),
                    ],
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

/// Shimmer Skeleton for Transaction List
class ShimmerTransactionList extends StatelessWidget {
  final int count;

  const ShimmerTransactionList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 0.6),
          ),
          child: Row(
            children: const [
              ShimmerBox(width: 40, height: 40, shape: BoxShape.circle),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120, height: 14),
                    SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 11),
                  ],
                ),
              ),
              ShimmerBox(width: 70, height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer Skeleton for Contacts List
class ShimmerContactList extends StatelessWidget {
  final int count;

  const ShimmerContactList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155), width: 0.8),
          ),
          child: Row(
            children: const [
              ShimmerBox(width: 44, height: 44, shape: BoxShape.circle),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 130, height: 15),
                    SizedBox(height: 8),
                    ShimmerBox(width: 90, height: 11),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShimmerBox(width: 75, height: 16),
                  SizedBox(height: 6),
                  ShimmerBox(width: 60, height: 16, borderRadius: BorderRadius.all(Radius.circular(8))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer Skeleton for Analytics Screen Overview
class ShimmerAnalyticsOverview extends StatelessWidget {
  const ShimmerAnalyticsOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 180, height: 18),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: ShimmerBox(height: 105, borderRadius: BorderRadius.all(Radius.circular(18)))),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(height: 105, borderRadius: BorderRadius.all(Radius.circular(18)))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: ShimmerBox(height: 105, borderRadius: BorderRadius.all(Radius.circular(18)))),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(height: 105, borderRadius: BorderRadius.all(Radius.circular(18)))),
              ],
            ),
            const SizedBox(height: 24),
            const ShimmerBox(height: 260, borderRadius: BorderRadius.all(Radius.circular(22))),
            const SizedBox(height: 20),
            const ShimmerBox(height: 220, borderRadius: BorderRadius.all(Radius.circular(22))),
          ],
        ),
      ),
    );
  }
}
