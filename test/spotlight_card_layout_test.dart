import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/spotlight_item.dart';
import 'package:way2news_clone/state/engagement_store.dart';

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

  group('like and dislike are one reaction', () {
    final store = EngagementStore.instance;
    setUp(store.reset);

    test('they cannot both be active', () {
      const k = 'article:react';
      store.seed(k, likeCount: 5, dislikeCount: 1, reaction: Reaction.like);
      expect(store.stateFor(k).liked, isTrue);
      expect(store.stateFor(k).disliked, isFalse);

      store.seed(k, reaction: Reaction.dislike);
      expect(store.stateFor(k).liked, isFalse);
      expect(store.stateFor(k).disliked, isTrue);
    });

    test('both counts are tracked, so dislike can show a number', () {
      const k = 'article:counts';
      store.applyServerCounts(k, {'like_count': 11, 'dislike_count': 3});
      expect(store.stateFor(k).likeCount, 11);
      expect(store.stateFor(k).dislikeCount, 3);
    });
  });
}
