import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Accents
  static const primary = Color(0xFFFF2300); // Vermilion bright red-orange
  static const primaryDark = Color(0xFFFF3000); // Bottom gradient red-orange
  static const accent = Color(0xFFFED915); // Vibrant Yellow
  static const brandBlue = Color(0xFF2563EB); // Interactive blue
  static const heartRed = Color(0xFFFF3B30); // Like/active icon red
  static const error = Color(0xFFDC2626); // Alert red

  // Light Mode Colors
  static const background = Color(0xFFFFFFFF); // Pure white background
  static const cardDark = Color(0xFF141414);
  static const textDark = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF8A8A8E);
  static const chipBg = Color(0xFFF0F0F2);
  static const borderLight = Color(0xFFE5E7EB);
  
  // Dark Mode Colors (Redesigned for Premium Readability & High Contrast)
  static const backgroundDark = Color(0xFF0B0F1A); // Deep navy, not pure black
  static const cardDarkNavy = Color(0xFF121826);   // Secondary cards / sheets
  static const surfaceElevatedDark = Color(0xFF1A2233); // Elevated surfaces / composer
  static const borderDark = Color(0xFF2A3441);     // Subtle dividers & borders
  
  // Dark Mode Text Colors
  static const textLight = Color(0xFFFFFFFF);      // 100% white primary text
  static const textSecondaryDark = Color(0xFFB0B8C5); // Light gray for metadata, usernames, subheads
  static const textCommentBodyDark = Color(0xFFE5E7EB); // Softer white for comment text & body
  static const textDisabledDark = Color(0xFF6B7280); // Disabled / subtle text
  static const iconMutedDark = Color(0xFF9CA3AF);  // Default inactive icons & placeholders
  
  // Reading & Article UI Tokens (Optimized for Telugu & Maximum Readability)
  static const readingTitleLight = Color(0xFF212121); // #212121 headline
  static const readingBodyLight = Color(0xFF424242);  // #424242 body, optimal contrast
  static const readingMetaLight = Color(0xFF6B7280);  // Accessible meta text
  static const readingTitleDark = Color(0xFFFFFFFF);  // Pure white headline in dark mode
  static const readingBodyDark = Color(0xFFE5E7EB);   // Soft white body in dark mode
  static const readingMetaDark = Color(0xFF9CA3AF);   // Muted gray metadata in dark mode
  
  // Backward compatibility aliases
  static const cardDarkSlate = cardDarkNavy;
  static const chipBgDark = surfaceElevatedDark;
}

class AppTheme {
  /// Returns a theme with a text style appropriate for [language]'s script.
  /// Poppins only covers Latin glyphs, so Hindi/Telugu/Tamil/etc. need a
  /// Noto Sans variant that actually has glyphs for that script — otherwise
  /// text renders with a mismatched fallback font or tofu boxes.
  static ThemeData light([String language = 'Telugu']) {
    final base = ThemeData.light();
    final textTheme = _textThemeFor(language, base);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ThemeData dark([String language = 'Telugu']) {
    final base = ThemeData.dark();
    final textTheme = _textThemeFor(language, base);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.brandBlue,
        surface: AppColors.cardDarkNavy,
        onSurface: AppColors.textLight,
        onPrimary: Colors.white,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        surfaceTintColor: AppColors.backgroundDark,
        iconTheme: IconThemeData(color: AppColors.textLight),
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textLight,
        displayColor: AppColors.textLight,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.iconMutedDark,
      ),
      splashFactory: InkRipple.splashFactory,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardDarkNavy,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.iconMutedDark,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardDarkNavy,
        modalBackgroundColor: AppColors.cardDarkNavy,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDarkNavy,
        surfaceTintColor: AppColors.cardDarkNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textCommentBodyDark,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDarkNavy,
        surfaceTintColor: AppColors.cardDarkNavy,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDark, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevatedDark,
        hintStyle: const TextStyle(color: AppColors.iconMutedDark, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.5),
        ),
      ),
      cardColor: AppColors.cardDarkNavy,
      dividerColor: AppColors.borderDark,
    );
  }

  static TextTheme _textThemeFor(String language, ThemeData base) {
    switch (language) {
      case 'Test':
        return base.textTheme;
      case 'English':
        return GoogleFonts.poppinsTextTheme(base.textTheme);
      case 'Telugu':
      default:
        return GoogleFonts.notoSansTeluguTextTheme(base.textTheme);
    }
  }
}
