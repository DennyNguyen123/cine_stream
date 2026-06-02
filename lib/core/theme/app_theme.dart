import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceVariant,
      ),
      focusColor: AppColors.primary,
      hoverColor: AppColors.primary.withValues(alpha: 0.5),
      listTileTheme: const ListTileThemeData(
        selectedColor: Colors.white,
        selectedTileColor: AppColors.primary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    );
  }
}
