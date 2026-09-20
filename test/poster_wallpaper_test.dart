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

  group('immersive without cropping the artwork', () {
    test('a blurred copy of the poster fills the background', () {
      // Same treatment the sponsored card uses: the screen reads as a
      // wallpaper while the poster itself stays whole in front.
      expect(code, contains('ImageFilter.blur'));
      expect(code, contains('BlendMode.darken'));
    });

    test('the poster itself is contained, never cropped', () {
      // These are designed sheets with branding at the very edges.
      expect(code, contains('fit: BoxFit.contain'));
    });

    test('the blurred layer does not steal taps from the pager', () {
      expect(code, contains('IgnorePointer'));
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
