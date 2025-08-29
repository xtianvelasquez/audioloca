import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4A148C);
  static const secondary = Color(0xFFCE93D8);
  static const secondaryLight = Color(0xFFF3E5F5);
  static const textLight = Colors.white;
}

class AppTextStyles {
  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const bodySmall = TextStyle(fontSize: 12, color: AppColors.primary);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: Colors.white,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    ),
  );
}
