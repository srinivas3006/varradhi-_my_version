import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final card = File('lib/widgets/poster_card.dart').readAsStringSync();
  final code = card
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('the poster fills the screen instead of sitting in a box', () {
    test('no fixed aspect box constrains the creative', () {
      // It used to sit in a 9:16 AspectRatio inside ~172px of chrome
      // padding, so a poster of any other shape showed grey bands.
      expect(code, isNot(contains('AspectRatio(')));
    });

    test('the artwork is positioned to fill', () {
      expect(code, contains('Positioned.fill'));
      expect(code, contains('StackFit.expand'));
    });

    test('no side gutters squeeze it', () {
      expect(code,
          isNot(contains('padding: const EdgeInsets.symmetric(horizontal: 16)')));
    });

    test('the grey slab backdrop is gone', () {
      expect(code, isNot(contains('isDark ? Colors.white10 : Colors.black12')));
    });
  });

  group('the poster is full screen in Spotlight', () {
    test('the artwork covers the whole page — no letterbox', () {
      expect(code, contains('fit: BoxFit.cover'));
      expect(code, isNot(contains('fit: BoxFit.contain')));
    });

    test('no blurred backdrop is needed behind it', () {
      expect(code, isNot(contains('ImageFilter.blur')));
    });

    test('exactly one Share control', () {
      expect('Icons.share_rounded'.allMatches(code).length, 1);
    });
  });

  group('poster detail screen', () {
    final detail = File('lib/screens/poster_detail_screen.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('has a single Share control (no duplicate in the app bar)', () {
      expect('Icons.share_rounded'.allMatches(detail).length, 1);
    });

    test('runs full screen, edge to edge', () {
      expect(detail, contains('extendBodyBehindAppBar: true'));
      expect(detail, contains('fit: BoxFit.cover'));
    });
  });

  group('chrome stays legible over any artwork', () {
    test('top and bottom controls sit on scrims', () {
      expect(code, contains('Colors.black54'));
      expect(code, contains('Colors.black87'));
      expect('LinearGradient'.allMatches(code).length, greaterThanOrEqualTo(2));
    });

    test('safe-area insets are still respected', () {
      expect(code, contains('padding.top'));
      expect(code, contains('padding.bottom'));
    });

    test('multi-design posters keep their page dots and counter', () {
      expect(code, contains('_Dots(count: _images.length'));
      expect(code, contains(r"'${_index + 1}/${_images.length}'"));
    });

    test('sharing still goes through the common sheet', () {
      expect(code, contains('ShareSheet.show'));
      expect(code, isNot(contains('Share.share(')));
    });
  });
}
