import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dark Mode Color Tokens', () {
    test('User-specified dark mode color constants are exact', () {
      expect(AppColors.backgroundDark, const Color(0xFF0B0F1A));
      expect(AppColors.cardDarkNavy, const Color(0xFF121826));
      expect(AppColors.surfaceElevatedDark, const Color(0xFF1A2233));
      expect(AppColors.borderDark, const Color(0xFF2A3441));
      expect(AppColors.textLight, const Color(0xFFFFFFFF));
      expect(AppColors.textSecondaryDark, const Color(0xFFB0B8C5));
      expect(AppColors.textCommentBodyDark, const Color(0xFFE5E7EB));
      expect(AppColors.textDisabledDark, const Color(0xFF6B7280));
      expect(AppColors.iconMutedDark, const Color(0xFF9CA3AF));
      expect(AppColors.heartRed, const Color(0xFFFF3B30));
      expect(AppColors.brandBlue, const Color(0xFF2563EB));
    });

    test('Dark theme configuration matches specifications', () {
      final darkTheme = AppTheme.dark('Test');

      expect(darkTheme.scaffoldBackgroundColor, AppColors.backgroundDark);
      expect(darkTheme.colorScheme.surface, AppColors.cardDarkNavy);
      expect(darkTheme.bottomSheetTheme.backgroundColor, AppColors.cardDarkNavy);
      expect(darkTheme.dialogTheme.backgroundColor, AppColors.cardDarkNavy);
      expect(darkTheme.cardTheme.color, AppColors.cardDarkNavy);
      expect(darkTheme.inputDecorationTheme.fillColor, AppColors.surfaceElevatedDark);
    });

    test('WCAG 4.5:1+ contrast ratio checks', () {
      // Relative luminance calculation according to WCAG 2.1
      double luminance(Color c) {
        double channel(double v) =>
            v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
        return 0.2126 * channel(c.r) +
            0.7152 * channel(c.g) +
            0.0722 * channel(c.b);
      }

      double contrastRatio(Color fg, Color bg) {
        final l1 = luminance(fg);
        final l2 = luminance(bg);
        final lighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        return (lighter + 0.05) / (darker + 0.05);
      }

      // Primary text on primary dark background
      final whiteOnDarkBg = contrastRatio(AppColors.textLight, AppColors.backgroundDark);
      expect(whiteOnDarkBg, greaterThanOrEqualTo(4.5),
          reason: 'Primary text must have at least 4.5:1 contrast on dark background');

      // Primary text on card surface
      final whiteOnCard = contrastRatio(AppColors.textLight, AppColors.cardDarkNavy);
      expect(whiteOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Primary text must have at least 4.5:1 contrast on card surface');

      // Secondary text on card surface
      final secOnCard = contrastRatio(AppColors.textSecondaryDark, AppColors.cardDarkNavy);
      expect(secOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text must have at least 4.5:1 contrast on card surface');

      // Comment body text on card surface
      final commentOnCard = contrastRatio(AppColors.textCommentBodyDark, AppColors.cardDarkNavy);
      expect(commentOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Comment body text must have at least 4.5:1 contrast on card surface');
    });
  });
}
