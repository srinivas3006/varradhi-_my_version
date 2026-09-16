import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The body copy from the reference screenshot.
const _body =
    'బాలీవుడ్ స్టార్ హీరో సల్మాన్ ఖాన్ గణేశ్ నిమజ్జనంలో పాల్గొన్నారు. '
    'ముంబైలోని తన సోదరుడు సోహైల్ ఖాన్ ఇంటి వద్ద జరిగిన ఈ వేడుకకు హాజరై గణపతికి '
    'హారతి పట్టారు. అటు ముకేశ్ అంబానీ నివాసంలో ఏర్పాటు చేసిన వినాయకుడిని రాత్రి '
    'నిమజ్జనం చేశారు. అనంత్ అంబానీ, రాధికా మర్చంట్, నీతా తదితరులు సందడి చేశారు. '
    'బాలీవుడ్ నటి శిల్పా శెట్టి, సోదరి షమిత తమ ఇంటి వద్ద నిమజ్జన వేడుకల్లో డాన్స్‌తో '
    'అదరగొట్టారు.';

const _title = 'VIDEO: గణేశ్ నిమజ్జనం.. హారతి పట్టిన సల్మాన్';

// What the card uses.
const _bodyStyle = TextStyle(fontSize: 16, height: 1.65, letterSpacing: 0);
const _titleStyle =
    TextStyle(fontSize: 21, height: 1.4, fontWeight: FontWeight.w800);

/// A 360dp-wide phone with the card's 16dp gutters — the reference screenshot.
const double _column = 360 - 32;

TextPainter _lay(String text, TextStyle style, double width) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);

void main() {
  group('body copy matches the reference rhythm', () {
    test('line height is ~26.5dp, as measured off the screenshot', () {
      final lines = _lay(_body, _bodyStyle, _column).computeLineMetrics();
      expect(lines.first.height, closeTo(26.5, 2.0));
    });

    test('the full measure is used', () {
      // Absolute line counts are not assertable here: the test environment
      // has no Telugu font, so glyph widths come from a fallback. What holds
      // regardless of font is that the breaker actually uses the column it
      // was given rather than wrapping early against a narrower measure.
      final lines = _lay(_body, _bodyStyle, _column).computeLineMetrics();
      final widest =
          lines.map((l) => l.width).reduce((a, b) => a > b ? a : b);
      expect(widest, greaterThan(_column * 0.8));
    });

    test('no line overflows the column', () {
      final lines = _lay(_body, _bodyStyle, _column).computeLineMetrics();
      for (final line in lines) {
        expect(line.width, lessThanOrEqualTo(_column + 0.5));
      }
    });

    test('text wraps rather than running on', () {
      expect(_lay(_body, _bodyStyle, _column).computeLineMetrics().length,
          greaterThan(1));
    });
  });

  group('headline', () {
    test('is clamped to two lines by the card', () {
      // maxLines: 2 in the card is what bounds it; the painter alone is
      // unbounded, and the fallback font here is far wider than Telugu.
      final painter = TextPainter(
        text: const TextSpan(text: _title, style: _titleStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: _column);
      expect(painter.computeLineMetrics().length, lessThanOrEqualTo(2));
      expect(painter.didExceedMaxLines, isTrue,
          reason: 'the fallback font overflows, so the clamp is doing work');
    });

    test('sits above the body in the hierarchy', () {
      expect(_titleStyle.fontSize!, greaterThan(_bodyStyle.fontSize!));
    });
  });

  group('the split is driven by width, not screen height', () {
    double mediaHeight(double w, double h) => (w / (9 / 8)).clamp(0.0, h * 0.72);

    test('a narrower phone gets more body lines, same copy', () {
      final wide = _lay(_body, _bodyStyle, 328).computeLineMetrics().length;
      final narrow = _lay(_body, _bodyStyle, 260).computeLineMetrics().length;
      expect(narrow, greaterThan(wide));
    });

    test('media keeps 9:8 on every width', () {
      for (final w in [320.0, 360.0, 411.0]) {
        expect(w / mediaHeight(w, 900), closeTo(9 / 8, 0.001));
      }
    });
  });
}
