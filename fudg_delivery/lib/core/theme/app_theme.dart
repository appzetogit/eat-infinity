import 'package:flutter/material.dart';
import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

/// Builds the light and dark [ThemeData] from [AppColors].
///
/// Both themes are defined here in full so a screen can lean on
/// `Theme.of(context)` for buttons, cards, inputs and text instead of
/// re-declaring the same decoration inline.
class AppTheme {
  AppTheme._();

  /// Corner radius used by cards, sheets and large buttons.
  static const double radiusLarge = 20;

  /// Corner radius for buttons, chips and inputs.
  static const double radiusMedium = 16;

  static ThemeData get lightTheme => _build(const AppPalette.light());

  static ThemeData get darkTheme => _build(const AppPalette.dark());

  static ThemeData _build(AppPalette c) {
    final brightness = c.isDark ? Brightness.dark : Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.onPrimary,
      secondary: AppColors.primaryDark,
      onSecondary: AppColors.onPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceVariant,
      onSurfaceVariant: c.textSecondary,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorBg,
      onErrorContainer: AppColors.errorText,
      outline: c.border,
      outlineVariant: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppConstants.appFontFamily,
      colorScheme: colorScheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      cardColor: c.surface,
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: AppConstants.appFontFamily,
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // Primary actions use Teal brand color with white text.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.55),
          elevation: 0,
          // Large touch target: this app is used one-handed, mid-delivery.
          // Not Size.fromHeight: an infinite min width crashes layout when the
          // button sits in a Row. Full-width buttons get width from parents.
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontFamily: AppConstants.appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: 1.5),
          // Not Size.fromHeight: an infinite min width crashes layout when the
          // button sits in a Row. Full-width buttons get width from parents.
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontFamily: AppConstants.appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          textStyle: const TextStyle(
            fontFamily: AppConstants.appFontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceVariant,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.success
              : AppColors.offline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppConstants.appFontFamily,
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppConstants.appFontFamily,
          color: c.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: AppConstants.appFontFamily,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: c.textSecondary,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      iconTheme: IconThemeData(color: c.textPrimary),

      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),

      textTheme: _textTheme(c),
    );
  }

  static TextTheme _textTheme(AppPalette c) {
    final primary = TextStyle(color: c.textPrimary);
    final secondary = TextStyle(color: c.textSecondary);
    return TextTheme(
      displayLarge: primary.copyWith(fontSize: 32, fontWeight: FontWeight.w900),
      headlineMedium: primary.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: primary.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      titleMedium: primary.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: primary.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: primary.copyWith(fontSize: 15),
      bodyMedium: primary.copyWith(fontSize: 14),
      bodySmall: secondary.copyWith(fontSize: 12),
      labelLarge: primary.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      labelSmall: secondary.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }
}
