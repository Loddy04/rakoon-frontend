import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

/// A vitrine-style card container with 3px architectural edges, hairline 1px borders,
/// pure white canvas background, and smooth bouncy press micro-interaction feedback on tap.
class PlayfulCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PlayfulCard({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor = AppColors.paper,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<PlayfulCard> createState() => _PlayfulCardState();
}

class _PlayfulCardState extends State<PlayfulCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppCurves.snappy,
        reverseCurve: AppCurves.bouncy,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = widget.border ??
        Border.all(color: AppColors.graphite, width: 1.0);
    final effectiveRadius = widget.borderRadius ??
        BorderRadius.circular(AppRadius.cards);
    final effectivePadding = widget.padding ??
        const EdgeInsets.all(AppSpacing.cardPadding);

    final cardChild = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: effectiveRadius,
        border: effectiveBorder,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) {
      return cardChild;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: cardChild,
      ),
    );
  }
}
