import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.darkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkSecondary,
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        error: AppColors.danger,
        onPrimary: AppColors.darkBackground,
        onSurface: AppColors.darkPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.darkPrimary),
      ),
      cardTheme: CardTheme(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(color: AppColors.darkPrimary, fontSize: 32, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(color: AppColors.darkPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: AppColors.darkPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: AppColors.darkSecondary, fontSize: 14),
        labelLarge: GoogleFonts.inter(color: AppColors.darkPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightSecondary,
        surface: AppColors.lightSurface,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        error: AppColors.danger,
        onPrimary: AppColors.lightBackground,
        onSurface: AppColors.lightPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.lightPrimary),
      ),
      cardTheme: CardTheme(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(color: AppColors.lightPrimary, fontSize: 32, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(color: AppColors.lightPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: AppColors.lightPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: AppColors.lightSecondary, fontSize: 14),
        labelLarge: GoogleFonts.inter(color: AppColors.lightPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}