import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/screens/splash_screen.dart';

void main() {
  SplashAdTiming timing(int seconds) =>
      SplashAdTiming.forConfiguredSeconds(seconds);

  group('splash ad duration', () {
    test('a full run is 30s with skip at 15s', () {
      final t = timing(30);
      expect(t.durationSeconds, 30);
      expect(t.skipAfterSeconds, 15);
    });

    test('no configured duration falls back to the full 30s run', () {
      for (final unset in [0, -1, -30]) {
        final t = timing(unset);
        expect(t.durationSeconds, 30, reason: 'input $unset');
        expect(t.skipAfterSeconds, 15, reason: 'input $unset');
      }
    });

    test('anything longer than 30s is capped at 30s', () {
      for (final over in [31, 60, 3600]) {
        final t = timing(over);
        expect(t.durationSeconds, 30, reason: 'input $over');
        expect(t.skipAfterSeconds, 15, reason: 'input $over');
      }
    });

    test('a shorter creative keeps its own duration', () {
      expect(timing(10).durationSeconds, 10);
      expect(timing(20).durationSeconds, 20);
    });
  });

  group('skip unlocks at the halfway mark', () {
    test('skip is half the duration, rounded up', () {
      expect(timing(30).skipAfterSeconds, 15);
      expect(timing(20).skipAfterSeconds, 10);
      expect(timing(10).skipAfterSeconds, 5);
      expect(timing(9).skipAfterSeconds, 5); // rounds up
      expect(timing(3).skipAfterSeconds, 2); // rounds up
    });

    test('skip is never live on the first frame', () {
      for (var s = 1; s <= 30; s++) {
        expect(timing(s).skipAfterSeconds, greaterThanOrEqualTo(1),
            reason: 'duration $s');
      }
    });

    test('skip never outlasts the ad itself', () {
      for (var s = 1; s <= 60; s++) {
        final t = timing(s);
        expect(t.skipAfterSeconds, lessThanOrEqualTo(t.durationSeconds),
            reason: 'duration $s');
      }
    });

    test('the reader never waits more than 15s to skip', () {
      for (var s = 0; s <= 3600; s += 7) {
        expect(timing(s).skipAfterSeconds, lessThanOrEqualTo(15),
            reason: 'configured $s');
      }
    });
  });
}
