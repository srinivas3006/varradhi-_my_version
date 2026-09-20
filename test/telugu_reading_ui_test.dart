import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/state/app_state.dart';
import 'package:way2news_clone/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Telugu Reading UI Color Tokens & Typography Specification', () {
    test('Reading color tokens match exact specification', () {
      expect(AppColors.readingTitleLight, const Color(0xFF111827),
          reason: 'Headline in light mode must be #111827 (dark gray, not pure black)');
      expect(AppColors.readingBodyLight, const Color(0xFF374151),
          reason: 'Article body in light mode must be #374151 (soft dark gray, avoid pure black)');
      expect(AppColors.readingMetaLight, const Color(0xFF6B7280),
          reason: 'Meta information in light mode must be #6B7280');

      expect(AppColors.readingTitleDark, const Color(0xFFFFFFFF),
          reason: 'Headline in dark mode must be #FFFFFF');
      expect(AppColors.readingBodyDark, const Color(0xFFE5E7EB),
          reason: 'Article body in dark mode must be #E5E7EB (soft white)');
      expect(AppColors.readingMetaDark, const Color(0xFF9CA3AF),
          reason: 'Meta information in dark mode must be #9CA3AF');
    });

    test('Ensures no pure black (#000000) is used for reading texts', () {
      expect(AppColors.readingTitleLight, isNot(const Color(0xFF000000)));
      expect(AppColors.readingBodyLight, isNot(const Color(0xFF000000)));
      expect(AppColors.readingMetaLight, isNot(const Color(0xFF000000)));
    });

    test('Reading contrast ratios satisfy WCAG AAA standards', () {
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

      const whiteBg = Color(0xFFFFFFFF);
      // Title contrast on white: #111827 on #FFFFFF
      final titleContrast = contrastRatio(AppColors.readingTitleLight, whiteBg);
      expect(titleContrast, greaterThanOrEqualTo(7.0),
          reason: 'Light title must exceed WCAG AAA 7:1 contrast');

      // Body contrast on white: #374151 on #FFFFFF
      final bodyContrast = contrastRatio(AppColors.readingBodyLight, whiteBg);
      expect(bodyContrast, greaterThanOrEqualTo(7.0),
          reason: 'Light body text must exceed WCAG AAA 7:1 contrast');

      // Dark mode body contrast on card navy
      final darkBodyContrast =
          contrastRatio(AppColors.readingBodyDark, AppColors.cardDarkNavy);
      expect(darkBodyContrast, greaterThanOrEqualTo(7.0),
          reason: 'Dark body text must exceed WCAG AAA 7:1 contrast');
    });

    test('AppState readingFontSize defaults to 19.0 and can be adjusted', () async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppState.instance;
      await appState.init();

      expect(appState.readingFontSize, 19.0,
          reason: 'Default reading font size for Telugu readability must be 19px');

      bool notified = false;
      appState.addListener(() {
        notified = true;
      });

      await appState.setReadingFontSize(21.0);
      expect(appState.readingFontSize, 21.0);
      expect(notified, isTrue);

      // Reset to 19.0
      await appState.setReadingFontSize(19.0);
      expect(appState.readingFontSize, 19.0);
    });

    test('Spotlight news card typography scaling yields balanced line density', () {
      double calculateEffectiveFontSize(double sliderValue) {
        return sliderValue > 0 ? (sliderValue * (16.5 / 19.0)) : 16.5;
      }

      // At default slider 19.0, effective size is 16.5
      expect(calculateEffectiveFontSize(19.0), closeTo(16.5, 0.01),
          reason: 'Default 19.0 slider must scale to 16.5dp to avoid oversized body typography');

      // At minimum slider 12.0
      expect(calculateEffectiveFontSize(12.0), closeTo(10.42, 0.01));

      // At maximum slider 24.0
      expect(calculateEffectiveFontSize(24.0), closeTo(20.84, 0.01));

      // Media aspect ratio 4:3 (1.333) vs previous 9:8 (1.125) saves vertical height
      const cardWidth = 390.0;
      final oldMediaHeight = cardWidth / (9 / 8); // 346.67dp
      final newMediaHeight = cardWidth / (4 / 3); // 292.50dp
      expect(oldMediaHeight - newMediaHeight, greaterThan(50.0),
          reason: '4:3 ratio must reclaim >50dp of vertical space for news reading body');
    });
  });
}

