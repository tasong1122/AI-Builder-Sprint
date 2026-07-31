import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );

  static ThemeData light() => _buildTheme(Brightness.light);

  static ThemeData dark() => _buildTheme(Brightness.dark);

  // 밝기 설정에 맞는 공통 Material 테마를 생성한다.
  static ThemeData _buildTheme(Brightness brightness) {
    final highlightColor = brightness == Brightness.dark
        ? AppColors.darkHighlight
        : AppColors.highlight;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: highlightColor,
      brightness: brightness,
    ).copyWith(primary: highlightColor);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: highlightColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }
}
