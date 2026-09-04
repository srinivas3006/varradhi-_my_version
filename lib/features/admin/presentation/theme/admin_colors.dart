import 'package:flutter/material.dart';

/// Color tokens for the Admin UGC Moderation console only. Deliberately
/// separate from the app's global AppColors/AppTheme (lib/theme/app_theme.dart)
/// so the admin console can use its own semantic success/warning/error
/// palette without changing colors anywhere else in the app.
class AdminColors {
  AdminColors._();

  static const Color primary = Color(0xFFFF4D00);
  static const Color accentSecondary = Color(0xFF2962FF);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFD32F2F);

  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color surfaceDark = Color(0xFF2C2C2C);
  static const Color scaffoldDark = Color(0xFF121212);

  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color scaffoldLight = Color(0xFFFFFFFF);

  static Color scaffold(bool isDark) => isDark ? scaffoldDark : scaffoldLight;
  static Color card(bool isDark) => isDark ? cardDark : Colors.white;
  static Color surface(bool isDark) => isDark ? surfaceDark : const Color(0xFFF5F5F5);
  static Color textPrimary(bool isDark) => isDark ? Colors.white : textPrimaryLight;
  static Color textSecondaryColor(bool isDark) => isDark ? Colors.white60 : textSecondary;
  static Color cardBorder(bool isDark) => isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
}
