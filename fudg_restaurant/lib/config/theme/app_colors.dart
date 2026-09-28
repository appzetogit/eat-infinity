import 'package:flutter/material.dart';

/// Centralized color palette for the app, based on the food app UI design.
class AppColors {
  // ==================== BRAND COLORS ====================
  static const Color primary = Color(0xFFF41222); // Fudg red
  static const Color primaryLight = Color(0xFFF64652);
  static const Color primaryDark = Color(0xFFCD0A17);

  // Tints of the brand color, for surfaces / borders / highlights
  static const Color primarySurfaceSoft = Color(0xFFFDECEE);
  static const Color primarySurface = Color(0xFFFBD5D8);
  static const Color primarySurfaceStrong = Color(0xFFF6A2A8);
  static const Color primaryBorder = Color(0xFFEF5D67);

  // ==================== DARK THEME COLORS ====================
  static const Color backgroundDark = Color(0xFF161925); // Deep Navy/Dark Grey
  static const Color surfaceDark = Color(0xFF222638); // Card background
  static const Color surfaceVariantDark = Color(
    0xFF2E3347,
  ); // Lighter surface for chips/inputs

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA0A5BA);

  // ==================== LIGHT THEME COLORS ====================
  // Designed to complement the dark theme structure
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFEEEEEE);

  static const Color textPrimaryLight = Color(0xFF1E1E1E);
  static const Color textSecondaryLight = Color(0xFF666666);

  // ==================== STATUS & ACCENT COLORS ====================
  static const Color success = Color(0xFF4ADE80); // Green for time/success
  static const Color rating = Color(0xFFFFB01D); // Yellow/Orange for stars
  static const Color error = Color(0xFFFF6464); // Red/Flame for calories/errors

  // Amber, for pending/warning states only — never as a brand accent
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFFF7E6);
  static const Color warningDark = Color(0xFF8A5A00);
}
