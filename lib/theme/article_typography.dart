import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography reserved for news article content.
///
/// Article headlines use Ramabhadra; article body/summary text uses Mandali.
/// Keeping these helpers separate from [AppTheme] prevents controls, nav,
/// settings, and other app chrome from inheriting article-only fonts.
class ArticleTypography {
  ArticleTypography._();

  static TextStyle heading({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.35,
    double letterSpacing = 0.0,
  }) {
    return GoogleFonts.ramabhadra(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.6,
    double letterSpacing = 0.0,
  }) {
    return GoogleFonts.mandali(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
