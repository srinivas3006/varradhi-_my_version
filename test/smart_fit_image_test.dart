import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/widgets/smart_fit_image.dart';

void main() {
  // Spotlight frame is width / 1.22.
  const frame = 1.22;
  const tol = 0.25;

  group('a photo is never zoomed into its frame', () {
    test('a 4:3 photo is close to the frame: fills it', () {
      expect(SmartFitImage.shouldCover(4 / 3, frame, tol), isTrue);
    });

    test('a square photo fills it with a small trim', () {
      expect(SmartFitImage.shouldCover(1.0, frame, tol), isTrue);
    });

    test('a 16:9 photo is shown whole instead of cropped', () {
      expect(SmartFitImage.shouldCover(16 / 9, frame, tol), isFalse);
    });

    test('a tall portrait is shown whole instead of cropped', () {
      expect(SmartFitImage.shouldCover(3 / 4, frame, tol), isFalse);
    });

    test('unknown sizes fall back to fill', () {
      expect(SmartFitImage.shouldCover(0, frame, tol), isTrue);
    });
  });
}
