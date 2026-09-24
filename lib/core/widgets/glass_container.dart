import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.7,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = color ??
        (isDark
            ? AppColors.darkSurface.withValues(alpha: opacity)
            : AppColors.lightSurface.withValues(alpha: opacity));

    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);
    final effectiveBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.4),
          width: 1,
        );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: boxShadow,
        borderRadius: effectiveRadius,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: defaultColor,
              borderRadius: effectiveRadius,
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
