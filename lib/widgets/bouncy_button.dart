import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

/// Style variants for [BouncyButton] aligned with Shupatto design system
enum BouncyButtonVariant {
  /// Primary action: Paper fill, Graphite text, 3px radius, 1px hairline border
  primaryPill,

  /// Chromatic accent action: Periwinkle fill, White text, 3px radius
  accentAction,

  /// Outlined display action: Transparent fill, 1px Graphite border, Graphite text
  outlined,

  /// Subtle secondary action: Soft grey fill, Graphite text
  confettiPink,
}

/// A highly responsive, bouncy interactive button wrapper featuring subtle micro-scale feedback on press.
class BouncyButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? text;
  final Widget? child;
  final IconData? icon;
  final BouncyButtonVariant variant;
  final bool isLoading;
  final bool isDisabled;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const BouncyButton({
    super.key,
    required this.onPressed,
    this.text,
    this.child,
    this.icon,
    this.variant = BouncyButtonVariant.primaryPill,
    this.isLoading = false,
    this.isDisabled = false,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
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

  bool get _canInteract =>
      !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

  void _onTapDown(TapDownDetails details) {
    if (_canInteract) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_canInteract) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (_canInteract) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Border border;

    switch (widget.variant) {
      case BouncyButtonVariant.primaryPill:
        backgroundColor = AppColors.paper;
        textColor = AppColors.graphite;
        border = Border.all(color: AppColors.graphite, width: 1.0);
        break;
      case BouncyButtonVariant.accentAction:
        backgroundColor = AppColors.periwinkle;
        textColor = AppColors.paper;
        border = Border.all(color: AppColors.periwinkle, width: 1.0);
        break;
      case BouncyButtonVariant.outlined:
        backgroundColor = Colors.transparent;
        textColor = AppColors.graphite;
        border = Border.all(color: AppColors.graphite, width: 1.0);
        break;
      case BouncyButtonVariant.confettiPink:
        backgroundColor = AppColors.accentSoft;
        textColor = AppColors.graphite;
        border = Border.all(color: AppColors.graphite, width: 1.0);
        break;
    }

    if (!widget.isDisabled && widget.onPressed == null) {
      backgroundColor = backgroundColor.withValues(alpha: 0.5);
      textColor = textColor.withValues(alpha: 0.5);
    }

    final effectiveRadius =
        widget.borderRadius ?? BorderRadius.circular(AppRadius.buttons);

    final content = widget.isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : (widget.child ??
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: textColor, size: 16),
                  const SizedBox(width: AppSpacing.s),
                ],
                if (widget.text != null)
                  Flexible(
                    child: Text(
                      widget.text!,
                      style: AppTextStyles.buttonLabel.copyWith(color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ));

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _canInteract ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: widget.width,
          height: widget.height,
          padding: widget.padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.cardPadding,
                vertical: 12.0,
              ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: effectiveRadius,
            border: border,
          ),
          child: Center(
            widthFactor: widget.width == null ? 1.0 : null,
            child: content,
          ),
        ),
      ),
    );
  }
}
