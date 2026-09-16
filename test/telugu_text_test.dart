import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Telugu from a real article: clusters here combine a base consonant with a
/// vowel sign, and in places a subjoined consonant (ottu).
const _telugu =
    'నల్గొండ జిల్లా డిండి మండలం మూతలతండా శివారులో సోమవారం వివాహిత నాగమణి బావిలో పడి మృతి చెందిన ఘటన కలకలం రేపింది';

void main() {
  group('grapheme-safe truncation', () {
    test('code-unit substring can orphan a combining mark', () {
      // Demonstrates the bug the fix avoids: UTF-16 indices land inside a
      // cluster, so the tail can begin with a dangling combining mark.
      var foundSplit = false;
      for (var i = 1; i < _telugu.length; i++) {
        final tail = _telugu.substring(i);
        if (tail.isEmpty) continue;
        // A Telugu combining vowel sign / virama leading a string is orphaned.
        final lead = tail.codeUnitAt(0);
        if (lead >= 0x0C3E && lead <= 0x0C56) {
          foundSplit = true;
          break;
        }
      }
      expect(foundSplit, isTrue,
          reason: 'substring must be able to split a cluster for this to matter');
    });

    test('characters.take never orphans a mark', () {
      for (var n = 1; n <= _telugu.characters.length; n++) {
        final cut = _telugu.characters.take(n).toString();
        expect(cut.characters.length, n);
        // Re-splitting the result yields whole clusters only.
        expect(_telugu.startsWith(cut), isTrue);
      }
    });

    test('a short string is returned whole', () {
      const short = 'నల్గొండ';
      expect(short.characters.take(150).toString(), short);
    });
  });

  group('line breaking is the engine\'s job', () {
    testWidgets('Telugu wraps at word boundaries within its width', (tester) async {
      const style = TextStyle(fontSize: 15.5, height: 1.65, letterSpacing: 0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 350,
              child: Text(_telugu, style: style),
            ),
          ),
        ),
      );

      final painter = TextPainter(
        text: const TextSpan(text: _telugu, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 350);

      final lines = painter.computeLineMetrics();

      // It wrapped rather than producing one giant line...
      expect(lines.length, greaterThan(1));
      // ...and no line exceeds the available width.
      for (final line in lines) {
        expect(line.width, lessThanOrEqualTo(350.0));
      }
      // Measured line height exceeds the nominal fontSize, which is why the
      // card asks for metrics instead of computing fontSize * height.
      expect(lines.first.height, greaterThan(style.fontSize!));
    });

    testWidgets('a narrower box yields more lines, same string', (tester) async {
      const style = TextStyle(fontSize: 15.5, height: 1.65);
      TextPainter paint(double w) => TextPainter(
            text: const TextSpan(text: _telugu, style: style),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: w);

      final wide = paint(350).computeLineMetrics().length;
      final narrow = paint(220).computeLineMetrics().length;
      expect(narrow, greaterThan(wide));
    });
  });
}
