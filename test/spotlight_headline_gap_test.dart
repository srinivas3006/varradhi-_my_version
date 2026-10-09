import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

void main() {
  group('headline sits tight on the story', () {
    test('line height is applied to the first and last lines too', () {
      const b = SpotlightNewsCard.tightLeading;
      expect(b.applyHeightToFirstAscent, isTrue,
          reason: "otherwise Mandali's tall ascent opens a gap above the "
              'first line of the story');
      expect(b.applyHeightToLastDescent, isTrue,
          reason: "otherwise Ramabhadra's descent opens a gap under the "
              'headline');
      expect(b.leadingDistribution, TextLeadingDistribution.even);
    });

    test('a small fixed gap between headline and story', () {
      expect(SpotlightNewsCard.headlineGap, lessThanOrEqualTo(6));
    });

    final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
        .readAsStringSync();

    test('headline, story and the fit measurement all use it', () {
      // Headline, story text, and the TextPainter that measures the story
      // (so Read more still lands on its own line).
      expect(
          RegExp(r'textHeightBehavior:\s*SpotlightNewsCard\.tightLeading')
              .allMatches(src)
              .length,
          3);
      expect(src, isNot(contains('applyHeightToFirstAscent: false')));
    });

    test('measured with the same text scale it is painted at', () {
      expect(src, contains('textScaler: MediaQuery.textScalerOf(context)'));
    });
  });
}
