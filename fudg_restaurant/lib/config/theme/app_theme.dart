import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

const double _borderRadius = 16.0;
const double _buttonBorderRadius = 30.0;
const double _buttonHeight = 56.0;
const String _fontFamily = "ManropeVariable";

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: _fontFamily,
  scaffoldBackgroundColor: AppColors.backgroundLight,
  primaryColor: AppColors.primary,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.primaryLight,
    surface: AppColors.surfaceLight,
    background: AppColors.backgroundLight,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimaryLight,
  ),

  // Typography
  textTheme:
      const TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineMedium: AppTextStyles.h4,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
      ).apply(
        fontFamily: _fontFamily,
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),

  // App Bar
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.surfaceLight,
    foregroundColor: AppColors.textPrimaryLight,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),

  // Elevated Button
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, _buttonHeight),
      textStyle: AppTextStyles.button.copyWith(fontFamily: _fontFamily),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
      elevation: 0,
    ),
  ),

  // Outlined Button
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary, width: 2),
      minimumSize: const Size(double.infinity, _buttonHeight),
      textStyle: AppTextStyles.button.copyWith(fontFamily: _fontFamily),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
    ),
  ),

  // Text Button
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTextStyles.button.copyWith(fontFamily: _fontFamily),
    ),
  ),

  // Progress Indicator
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
  ),

  // Card Theme
  cardTheme: CardThemeData(
    color: AppColors.surfaceLight,
    elevation: 2,
    shadowColor: Colors.black.withOpacity(0.05),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),
    ),
    clipBehavior: Clip.antiAlias,
  ),

  // Input Decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariantLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    hintStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textSecondaryLight,
    ),
    labelStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
    ),
  ),

  // Bottom Navigation Bar
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceLight,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondaryLight,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),

  // Chip Theme
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceVariantLight,
    labelStyle: AppTextStyles.bodySmall.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),
    side: BorderSide.none,
  ),

  // SnackBar / Toast Theme
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: const Color(0xFF1E1E1E),
    contentTextStyle: const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    elevation: 6,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
);

// ==================== DARK THEME ====================
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: _fontFamily,
  scaffoldBackgroundColor: AppColors.backgroundDark,
  primaryColor: AppColors.primary,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.primaryLight,
    surface: AppColors.surfaceDark,
    background: AppColors.backgroundDark,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimaryDark,
  ),

  // Typography
  textTheme:
      const TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineMedium: AppTextStyles.h4,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
      ).apply(
        fontFamily: _fontFamily,
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),

  // App Bar
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      fontFamily: _fontFamily,
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),

  // Elevated Button
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, _buttonHeight),
      textStyle: AppTextStyles.button.copyWith(fontFamily: _fontFamily),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
      elevation: 0,
    ),
  ),

  // Outlined Button
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary, width: 2),
      minimumSize: const Size(double.infinity, _buttonHeight),
      textStyle: AppTextStyles.button.copyWith(fontFamily: _fontFamily),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
    ),
  ),

  // Text Button
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTextStyles.button.copyWith(fontFamily: _fontFamily),
    ),
  ),

  // Progress Indicator
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
  ),

  // Card Theme
  cardTheme: CardThemeData(
    color: AppColors.surfaceDark,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),
    ),
    clipBehavior: Clip.antiAlias,
  ),

  // Input Decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariantDark,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    hintStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textSecondaryDark,
    ),
    labelStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryDark,
    ),
  ),

  // Bottom Navigation Bar
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.backgroundDark,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondaryDark,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),

  // Chip Theme
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceVariantDark,
    labelStyle: AppTextStyles.bodySmall.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryDark,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),
    side: BorderSide.none,
  ),

  // SnackBar / Toast Theme
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: const Color(0xFF2C2C2C),
    contentTextStyle: const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    elevation: 6,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
);
