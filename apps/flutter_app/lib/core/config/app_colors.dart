import 'package:flutter/material.dart';

/// Velora design tokens — single source of truth for color & gradients.
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════
  // Dark mode
  // ═══════════════════════════════════════════
  static const Color darkBackground = Color(0xFF0A0A0B);
  static const Color darkSurface = Color(0xFF141416);
  static const Color darkSurfaceVariant = Color(0xFF1C1C1F);
  static const Color darkBorder = Color(0xFF2A2A2E);
  static const Color darkDivider = Color(0xFF1F1F23);

  static const Color darkPrimary = Color(0xFFF5F5F7);
  static const Color darkSecondary = Color(0xFF8E8E93);

  static const Color darkAccent = Color(0xFF6366F1);
  static const Color darkAccentSecondary = Color(0xFF8B5CF6);

  // ═══════════════════════════════════════════
  // Light mode
  // ═══════════════════════════════════════════
  static const Color lightBackground = Color(0xFFF9FAFB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF3F4F6);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightDivider = Color(0xFFE5E7EB);

  static const Color lightPrimary = Color(0xFF111827);
  static const Color lightSecondary = Color(0xFF6B7280);

  static const Color lightAccent = Color(0xFF6366F1);
  static const Color lightAccentSecondary = Color(0xFF8B5CF6);

  // ═══════════════════════════════════════════
  // Semantic
  // ═══════════════════════════════════════════
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFF87171);
  static const Color dangerDark = Color(0xFFDC2626);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);

  // ═══════════════════════════════════════════
  // Extended palette
  // ═══════════════════════════════════════════
  static const Color purple = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color teal = Color(0xFF14B8A6);
  static const Color orange = Color(0xFFF97316);

  // ═══════════════════════════════════════════
  // Gradients
  // ═══════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient chartGradient = LinearGradient(
    colors: [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF97316),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ═══════════════════════════════════════════
  // Overlay helpers
  // ═══════════════════════════════════════════
  static Color accentWithOpacity(double opacity, {bool isDark = true}) =>
      (isDark ? darkAccent : lightAccent).withOpacity(opacity);

  static Color surfaceWithOpacity(double opacity, {bool isDark = true}) =>
      (isDark ? darkSurface : lightSurface).withOpacity(opacity);

  static Color successWithOpacity(double opacity) => success.withOpacity(opacity);
  static Color warningWithOpacity(double opacity) => warning.withOpacity(opacity);
  static Color dangerWithOpacity(double opacity) => danger.withOpacity(opacity);
  static Color infoWithOpacity(double opacity) => info.withOpacity(opacity);

  // ═══════════════════════════════════════════
  // Charts
  // ═══════════════════════════════════════════
  static const List<Color> chartColors = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
  ];

  static Color chartColorAt(int index) =>
      chartColors[index % chartColors.length];
}
