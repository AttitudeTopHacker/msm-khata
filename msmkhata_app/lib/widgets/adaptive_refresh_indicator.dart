import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps [child] in a [RefreshIndicator] on mobile platforms (Android & iOS).
///
/// On Desktop platforms (Linux, Windows, macOS) and Web:
/// Pull-to-refresh is completely disabled, eliminating awkward mouse-drag jitter
/// and unwanted bouncy scroll physics, providing a crisp, native desktop experience.
class AdaptiveRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double strokeWidth;

  const AdaptiveRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.strokeWidth = 2.5,
  });

  /// Whether current platform is a desktop operating system (Linux, Windows, macOS)
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Provides standard desktop clamping physics on Desktop,
  /// and responsive bouncing/pull physics on mobile.
  static ScrollPhysics scrollPhysics({
    ScrollPhysics mobilePhysics = const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  }) {
    if (isDesktop) {
      return const ClampingScrollPhysics();
    }
    return mobilePhysics;
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return child; // Zero pull-to-refresh gesture on Desktop!
    }
    return RefreshIndicator(
      color: color ?? const Color(0xFF818CF8),
      backgroundColor: backgroundColor ?? const Color(0xFF1E293B),
      strokeWidth: strokeWidth,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
