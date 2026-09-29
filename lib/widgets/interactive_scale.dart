import 'package:flutter/material.dart';

/// Provides the active:scale-95 transition-transform animation on pressed/active states.
class InteractiveScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  const InteractiveScale({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<InteractiveScale> {
  bool _isDown = false;

  void _setDown(bool value) {
    if (mounted && _isDown != value) {
      setState(() => _isDown = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget animated = AnimatedScale(
      scale: _isDown ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return Listener(
        onPointerDown: (_) => _setDown(true),
        onPointerUp: (_) => _setDown(false),
        onPointerCancel: (_) => _setDown(false),
        child: GestureDetector(
          behavior: widget.behavior,
          onTap: widget.onTap,
          child: animated,
        ),
      );
    }

    return Listener(
      onPointerDown: (_) => _setDown(true),
      onPointerUp: (_) => _setDown(false),
      onPointerCancel: (_) => _setDown(false),
      child: animated,
    );
  }
}
