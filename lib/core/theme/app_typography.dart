import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const codeStyle = TextStyle(
    fontSize: 14,
    fontFamily: 'monospace',
    fontFamilyFallback: ['Courier New', 'Courier'],
    color: AppColors.primary,
  );
}
