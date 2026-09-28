import 'package:flutter/material.dart';

class AppColors {
  // ==================== BRAND COLORS ====================
  // Mutable (not const): reassigned by ThemeColorNotifier when the user picks
  // an app theme color, so every one of the hundreds of `AppColors.primary`
  // read sites app-wide picks up the new value on the next rebuild without
  // each of them needing to watch a provider individually.
  static Color primary = const Color(0xFFF41222);
  static Color primaryButton = const Color(0xFFF41222);

  // ==================== DERIVED BRAND SHADES ====================
  // Getters, not fields: each is recomputed from the *current* [primary] on
  // every read, so the tints/shades that used to be hardcoded orange hexes
  // (badge backgrounds, chip fills, tinted borders, gradient ends, dark-mode
  // tinted containers) follow the user's picked theme color for free.
  //
  // Saturation is clamped rather than taken raw so a very saturated primary
  // (orange, at 1.0) does not produce garish pale tints, and a muted one still
  // reads as tinted rather than grey.
  static HSLColor get _hsl => HSLColor.fromColor(primary);

  static Color _shade(double lightness, double saturation) =>
      _hsl.withLightness(lightness).withSaturation(saturation).toColor();

  /// Slightly lighter accent — secondary gradient stop, hover/active fills.
  static Color get primaryLight => _shade(0.62, _hsl.saturation);

  /// Darker brand shade — gradient ends, pressed states, emphasis icons.
  static Color get primaryDeep => _shade(0.42, _hsl.saturation);

  /// Strong readable brand text/icon color sitting on a [primaryTint] fill.
  static Color get primaryDeepText => _shade(0.30, (_hsl.saturation * 0.85).clamp(0.0, 0.9));

  /// Palest brand wash — section/screen backgrounds, snackbar fills.
  static Color get primaryTint => _shade(0.96, (_hsl.saturation * 0.9).clamp(0.0, 1.0));

  /// Light brand fill — badge/chip backgrounds, selected list rows.
  static Color get primaryTintStrong => _shade(0.91, (_hsl.saturation * 0.9).clamp(0.0, 1.0));

  /// Muted brand fill — tinted borders, dividers, disabled brand surfaces.
  static Color get primarySoft => _shade(0.80, (_hsl.saturation * 0.9).clamp(0.0, 1.0));

  /// Dark-mode equivalent of [primaryTint] — subtly tinted dark container.
  static Color get primaryTintDark => _shade(0.12, (_hsl.saturation * 0.35).clamp(0.0, 0.45));

  /// Dark-mode equivalent of [primaryTintStrong] — a step more visible.
  static Color get primaryTintDarkStrong => _shade(0.20, (_hsl.saturation * 0.4).clamp(0.0, 0.5));

  /// Brand tint at [alpha] opacity — for overlays, shadows and glows that used
  /// to be written as `Color(0x66FF7A00)` or `primary.withOpacity(...)`.
  static Color primaryAlpha(double alpha) => primary.withValues(alpha: alpha);

  // ==================== DARK THEME COLORS ====================
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1B1B1B);
  static const Color cardDark = Color(0xFF242424);
  static const Color darkContainer = Color(0xFF2A2A2A);
  static const Color darkBorder = Color(0xFF3D3D3D);
  
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
  static const Color borderDark = Color(0xFF303030);

  // ==================== LIGHT THEME COLORS ====================
  static const Color backgroundLight = Color(0xFFF7F8FA); // Premium off-white
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color secondarySurfaceLight = Color(0xFFF4F5F7);
  static const Color lightContainer = Color(0xFFF9FAFB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color lightGreyBg = Color(0xFFF0F0F0);

  static const Color textPrimaryLight = Color(0xFF121212); // From spec
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textSecondaryLight = Color(0xFF6B7280); // From spec
  static const Color borderLight = Color(0xFFE9ECEF); // From spec
  static const Color borderSubtle = Color(0xFFE0E0E0);
  static const Color borderExtraSubtle = Color(0xFFEEEEEE);
  static const Color dividerLight = Color(0xFFF1F3F5); // From spec
  static const Color shadow1 = Color(0x14000000); // 0.08 opacity black
  static const Color shadow2 = Color(0x0A000000); // 0.04 opacity black

  // ==================== STATUS & ACCENT COLORS ====================
  static const Color success = Color(0xFF39C96B); 
  static const Color rating = Color(0xFFFFB01D); // Keeping rating star yellow/orange
  static const Color ratingStar = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF6464);
  static const Color accentPurple = Color(0xFF5A4099);
  static const Color accentPink = Color(0xFFFF4B72);
  static const Color accentBlue = Color(0xFF4B7BFF);
}
