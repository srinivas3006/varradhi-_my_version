import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/screens/news_detail_screen.dart').readAsStringSync();
  final code = src
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('there is one share control, not three', () {
    test('only a single share icon remains', () {
      // The screen carried three, all calling _share(): one over the hero
      // image, an orange one under it, and the engagement bar's.
      expect('Icons.share_rounded'.allMatches(code).length, 1);
    });

    test('the surviving one is in the engagement bar', () {
      expect(code.indexOf('Icons.share_rounded'),
          greaterThan(code.indexOf('_buildReactionSection')));
    });

    test('bookmark is still reachable from the header', () {
      expect(code, contains('Icons.bookmark_rounded'));
    });
  });

  group('the ad slot runs for every article kind', () {
    test('an article-zone banner is placed', () {
      expect(code, contains("BannerAdSlot(placementZone: 'article')"));
    });

    test('it is no longer gated behind the UGC check', () {
      // It sat inside `if (!_isUgc)`, so community posts never carried one.
      final gate = code.indexOf('if (!_isUgc) ...[');
      final slot = code.indexOf("BannerAdSlot(placementZone: 'article')");
      final gateEnd = code.indexOf('],', gate);
      expect(slot, greaterThan(gateEnd),
          reason: 'the slot must sit outside the UGC-only block');
    });
  });

  group('the screen survives accessibility text scaling', () {
    test('scale is clamped for the whole subtree', () {
      expect(code, contains('MediaQuery.withClampedTextScaling'));
      expect(code, contains('_clampedTextScale(context)'));
    });

    test('the clamp caps rather than discards', () {
      expect(code, contains('.clamp(1.0, 1.3)'));
    });
  });

  group('text-to-speech is wired to the existing service', () {
    test('it uses AppTtsService rather than a second engine', () {
      expect(code, contains('AppTtsService.instance'));
      expect(code, contains('toggleArticleTts'));
    });

    test('playback stops when the screen goes away', () {
      expect(code, contains('AppTtsService.instance.stop()'));
    });
  });

  group('merge leftovers are gone', () {
    test('no unreferenced reaction helpers remain', () {
      expect(code, isNot(contains("_toggleLike() => _toggleReaction")));
      expect(code, isNot(contains("_toggleDislike() => _toggleReaction")));
    });
  });
}
