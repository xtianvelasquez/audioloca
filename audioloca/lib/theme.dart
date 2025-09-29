import 'package:flutter/material.dart';

class AppColors {
  static const color1 = Color(0xFF4A148C);
  static const color2 = Color(0xFFCE93D8);
  static const color3 = Color(0xFFF3E5F5);

  static const light = Colors.white;
  static const dark = Colors.black;
}

class AppTextStyles {
  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.color1,
  );

  static const subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.color1,
  );

  static const keyword = TextStyle(fontSize: 12, color: AppColors.color1);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.color1,
        foregroundColor: AppColors.light,
        shape: const StadiumBorder(),
      ),
    ),
  );
}
