import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final bool isOutline;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isOutline = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutline
                    ? AppColors.primary
                    : (textColor ?? Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: isOutline
                ? (textColor ?? AppColors.primary)
                : (textColor ?? Colors.white),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTypography.labelLarge(
            isOutline
                ? (textColor ?? AppColors.primary)
                : (textColor ?? Colors.white),
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );

    if (isOutline) {
      return PressableScale(
        onTap: isLoading ? null : onPressed,
        child: Container(
          width: isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      );
    }

    return PressableScale(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: backgroundColor == null ? AppColors.primaryGradient : null,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? AppColors.primary).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
