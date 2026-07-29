import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle button = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );
}
