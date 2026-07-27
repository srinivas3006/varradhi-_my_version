import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFFF2300); // Vermilion bright red-orange
  static const primaryDark = Color(0xFFFF3000); // Bottom gradient red-orange
  static const accent = Color(0xFFFED915); // Vibrant Yellow
  static const background = Color(0xFFFFFFFF); // Pure white background
  static const cardDark = Color(0xFF141414);
  static const textDark = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF8A8A8E);
  static const chipBg = Color(0xFFF0F0F2);
  
  // Dark mode explicit colors (WCAG compliant)
  static const backgroundDark = Color(0xFF0F172A); // deep slate
  static const textLight = Color(0xFFF8FAFC); // crisp off-white
  static const cardDarkSlate = Color(0xFF1E293B);
  static const chipBgDark = Color(0xFF334155);
}

class AppTheme {
  /// Returns a theme with a text style appropriate for [language]'s script.
  /// Poppins only covers Latin glyphs, so Hindi/Telugu/Tamil/etc. need a
  /// Noto Sans variant that actually has glyphs for that script — otherwise
  /// text renders with a mismatched fallback font or tofu boxes.
  static ThemeData light([String language = 'English']) {
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

  static ThemeData dark([String language = 'English']) {
    final base = ThemeData.dark();
    final textTheme = _textThemeFor(language, base);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.cardDarkSlate,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        surfaceTintColor: AppColors.backgroundDark,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textLight,
        displayColor: AppColors.textLight,
      ),
      splashFactory: InkRipple.splashFactory,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardDarkSlate,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
      ),
      cardColor: AppColors.cardDarkSlate,
      dividerColor: Colors.white24,
    );
  }

  static TextTheme _textThemeFor(String language, ThemeData base) {
    switch (language) {
      case 'Hindi':
      case 'Marathi':
        return GoogleFonts.notoSansDevanagariTextTheme(base.textTheme);
      case 'Telugu':
        return GoogleFonts.notoSansTeluguTextTheme(base.textTheme);
      case 'Tamil':
        return GoogleFonts.notoSansTamilTextTheme(base.textTheme);
      case 'Kannada':
        return GoogleFonts.notoSansKannadaTextTheme(base.textTheme);
      case 'Bengali':
        return GoogleFonts.notoSansBengaliTextTheme(base.textTheme);
      case 'Malayalam':
        return GoogleFonts.notoSansMalayalamTextTheme(base.textTheme);
      case 'Gujarati':
        return GoogleFonts.notoSansGujaratiTextTheme(base.textTheme);
      case 'English':
      default:
        return GoogleFonts.poppinsTextTheme(base.textTheme);
    }
  }
}
