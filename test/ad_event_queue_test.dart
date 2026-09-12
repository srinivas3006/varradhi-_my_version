import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/ads/ad_event_queue.dart';

void main() {
  group('AdEventQueue Tests', () {
    late AdEventQueue queue;

    setUp(() {
      queue = AdEventQueue.instance;
      queue.reset();
    });

    tearDown(() {
      queue.reset();
    });

    test('ignores events with empty or whitespace adId', () {
      queue.enqueue(adId: '', eventType: 'impression');
      queue.enqueue(adId: '   ', eventType: 'impression');
      expect(queue.pendingCount, 0);
    });

    test('enqueues valid events with normalized lowercase eventType', () {
      queue.enqueue(
        adId: 'ad_test_1',
        eventType: 'IMPRESSION',
        placementZone: 'feed',
      );

      expect(queue.pendingCount, 1);
    });

    test('reset clears all pending queue items', () {
      queue.enqueue(adId: 'ad_1', eventType: 'impression');
      queue.enqueue(adId: 'ad_2', eventType: 'viewability');
      expect(queue.pendingCount, 2);

      queue.reset();
      expect(queue.pendingCount, 0);
    });

    test('AdEvent serialization and toString formatting', () {
      final event = AdEvent(
        adId: 'ad_ser',
        eventType: 'click',
        placementZone: 'article',
      );

      final map = event.toJson();
      expect(map['ad_id'], 'ad_ser');
      expect(map['event_type'], 'click');
      expect(map['placement_zone'], 'article');
      expect(event.toString().contains('ad_ser'), isTrue);
    });
  });
}
