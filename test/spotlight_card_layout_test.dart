import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/spotlight_item.dart';

void main() {
  group('media is 9:8 from width, not a share of height', () {
    // Mirrors the card: height = width / (9/8).
    double mediaHeight(double width, double height) =>
        (width / (9 / 8)).clamp(0.0, height * 0.72);

    test('the same shape on every device', () {
      for (final w in [320.0, 360.0, 390.0, 430.0]) {
        final h = mediaHeight(w, 900);
        expect(w / h, closeTo(9 / 8, 0.001), reason: 'width $w');
      }
    });

    test('a tall phone does not get a taller image', () {
      // Same width, very different screen heights.
      expect(mediaHeight(390, 800), mediaHeight(390, 1000));
    });

    test('capped so a short screen still leaves room for the headline', () {
      final h = mediaHeight(390, 400);
      expect(h, lessThanOrEqualTo(400 * 0.72));
    });
  });

  group('chrome visibility by card type', () {
    test('ads and posters hide the header and bottom bar', () {
      expect(SpotlightType.ad.isImmersiveStory, isTrue);
      expect(SpotlightType.poster.isImmersiveStory, isTrue);
    });

    test('polls keep theirs, since the controls are the card', () {
      expect(SpotlightType.poll.isImmersiveStory, isFalse);
      expect(SpotlightType.infoCard.isImmersiveStory, isFalse);
    });
  });


  group('the media is an exact square below the status bar', () {
    // Mirrors the card: height = width, capped only on a wide/landscape
    // screen at 62% of the height left under the status band.
    double mediaHeight(double w, double h, {double statusBar = 24}) =>
        w.clamp(0.0, (h - statusBar) * 0.62);

    const phones = <String, List<double>>{
      'compact 360x640': [360, 640],
      'pixel 4a 393x851': [393, 851],
      'pixel 7 412x915': [412, 915],
      'tall 412x1000': [412, 1000],
      'very tall 360x1080': [360, 1080],
    };

    phones.forEach((name, size) {
      test('$name is 1:1', () {
        expect(mediaHeight(size[0], size[1]), size[0]);
      });
    });

    test('a taller screen gets no more image, only more story', () {
      expect(mediaHeight(412, 1000), mediaHeight(412, 915));
    });

    test('the cap still stops a wide screen eating the card', () {
      expect(mediaHeight(2000, 800), lessThanOrEqualTo((800 - 24) * 0.62));
    });

    final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
        .readAsStringSync();

    test('the image starts below a black status-bar band', () {
      // The band belongs to the screen, and the pager starts under it, so a
      // card sliding in during a swipe never carries a black strip above
      // its image.
      final screen = File('lib/spotlight/spotlight_screen.dart')
          .readAsStringSync();
      expect(screen, contains('child: ColoredBox(color: Colors.black)'));
      expect(screen, contains('top: statusBarHeight,'));
      expect(screen, contains('removeTop: true'));

      expect(src, isNot(contains('statusBarHeight')));
      expect(src, isNot(contains('ColoredBox(color: Colors.black)')));
      expect(src, contains('top: mediaHeight,'));
    });

    test('the contact email is no longer shown under the headline', () {
      expect(src, isNot(contains('vaaradhinewsapp@gmail.com')));
    });
  });

  group('body type scales with the room available', () {
    double font(double bodyHeight, {double preference = 1.0}) =>
        (15.0 * (bodyHeight / 214.0).clamp(1.0, 1.30) * preference)
            .clamp(14.0, 21.0);

    test('a compact screen keeps the reference size', () {
      expect(font(214), closeTo(15.0, 0.01));
    });

    test('a taller screen gets larger type, not phone-sized type', () {
      expect(font(500), greaterThan(font(214)));
    });

    test('scaling stops rather than running away', () {
      // Holding the line count constant would need 44pt on a tall phone.
      expect(font(2000), lessThanOrEqualTo(21.0));
    });

    test('the reader preference still moves it', () {
      expect(font(400, preference: 24 / 19), greaterThan(font(400)));
      expect(font(400, preference: 12 / 19), lessThan(font(400)));
    });

    test('preference cannot push type out of a readable range', () {
      expect(font(400, preference: 5.0), lessThanOrEqualTo(21.0));
      expect(font(400, preference: 0.1), greaterThanOrEqualTo(14.0));
    });
  });

  group('accessibility text scale cannot overflow the chrome', () {
    // The headline, meta row and action bar are laid out at fixed sizes
    // against a measured budget. Android's scale multiplies all of them
    // without the budget being recomputed, so at 150% they overflowed before
    // the body was even measured.
    double clamped(double systemScale) => systemScale.clamp(1.0, 1.3);

    test('a normal scale passes through untouched', () {
      expect(clamped(1.0), 1.0);
    });

    test('a moderate scale still reaches the reader', () {
      expect(clamped(1.2), closeTo(1.2, 0.001));
    });

    test('an extreme scale is capped rather than ignored', () {
      // Capped, not discarded: 1.3x still helps, and body type already grows
      // with available height for large-text readers.
      expect(clamped(2.0), 1.3);
      expect(clamped(1.5), 1.3);
    });

    test('a scale below 1 never shrinks the card', () {
      expect(clamped(0.8), 1.0);
    });

    test('the card applies the clamp to its whole subtree', () {
      final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
          .readAsStringSync();
      expect(src, contains('MediaQuery.withClampedTextScaling'));
      expect(src, contains('MediaQuery.textScalerOf(context)'));
    });
  });

  group('the card keeps its own overflow escape', () {
    test('long copy truncates to Read More rather than scrolling', () {
      // FitOrScroll suits the poll and info cards, which are content
      // columns. This card is a Stack of Positioned children and needs a
      // bounded height, so a scroll view would break it outright. Tapping
      // through to the detail screen is the escape.
      final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
          .readAsStringSync();
      expect(src, contains('shouldShowReadMore'));
      expect(src, contains('_navigateToDetail'));
      expect(src, isNot(contains('FitOrScroll')));
    });
  });
}
