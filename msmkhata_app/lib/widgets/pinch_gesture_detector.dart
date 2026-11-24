import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wraps any widget tree to detect 2-finger or trackpad "Pinch In" gestures
/// completely passively without intercepting or blocking standard scrolling,
/// tapping, or pull-to-refresh gestures.
class PinchGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onPinchIn;

  const PinchGestureDetector({
    super.key,
    required this.child,
    required this.onPinchIn,
  });

  @override
  State<PinchGestureDetector> createState() => _PinchGestureDetectorState();
}

class _PinchGestureDetectorState extends State<PinchGestureDetector> {
  final Map<int, Offset> _pointerPositions = {};
  double? _initialDistance;
  DateTime _lastTriggerTime = DateTime(2000);

  void _trigger() {
    final now = DateTime.now();
    if (now.difference(_lastTriggerTime).inMilliseconds < 1200) return;
    _lastTriggerTime = now;
    _pointerPositions.clear();
    _initialDistance = null;
    widget.onPinchIn();
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Only register pointer if below top appbar zone (> 70px) to safeguard top pull-to-refresh
    if (event.position.dy > 70) {
      _pointerPositions[event.pointer] = event.position;
      if (_pointerPositions.length == 2) {
        final pts = _pointerPositions.values.toList();
        _initialDistance = (pts[0] - pts[1]).distance;
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.position;

    // Multi-touch pinch-in detection (2 fingers on Android / Touchscreen)
    if (_pointerPositions.length >= 2 && _initialDistance != null && _initialDistance! > 40) {
      final pts = _pointerPositions.values.toList();
      final currentDistance = (pts[0] - pts[1]).distance;
      final scale = currentDistance / _initialDistance!;

      // Pinch-in: fingers moved towards each other by >= 22%
      if (scale < 0.78) {
        _trigger();
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length < 2) {
      _initialDistance = null;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length < 2) {
      _initialDistance = null;
    }
  }

  // Desktop Trackpad Pinch-In Detection (Linux libinput, macOS, Windows)
  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    // On trackpad pinch-in gesture, event.scale contracts (< 0.85)
    if (event.scale > 0 && event.scale < 0.85) {
      _trigger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      onPointerPanZoomUpdate: _handlePanZoomUpdate,
      child: widget.child,
    );
  }
}
