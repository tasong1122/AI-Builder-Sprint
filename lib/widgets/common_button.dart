import 'package:flutter/material.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

class CommonButton extends StatelessWidget {
  const CommonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.height = AppDimensions.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBackgroundColor = backgroundColor ?? colorScheme.primary;
    final resolvedForegroundColor = foregroundColor ?? colorScheme.onPrimary;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: resolvedBackgroundColor,
          foregroundColor: resolvedForegroundColor,
          disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              height / 2 < AppDimensions.defaultBorderRadius
                  ? height / 2
                  : AppDimensions.defaultBorderRadius,
            ),
          ),
          textStyle: AppTextStyles.button,
        ),
        child: isLoading
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  color: resolvedForegroundColor,
                  strokeWidth: 2,
                ),
              )
            : Text(label),
      ),
    );
  }
}
