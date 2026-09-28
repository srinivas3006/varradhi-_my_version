import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/widgets/smart_fit_image.dart';

void main() {
  // Spotlight frame is width / 1.22.
  const frame = 1.22;

  group('photos fill the frame without blur bands', () {
    test('a photo taller than the frame keeps its top (no cut-off heads)',
        () {
      final a = SmartFitImage.alignmentFor(3 / 4, frame);
      expect(a.y, lessThan(0));
    });

    test('a wide 16:9 photo is centred', () {
      expect(SmartFitImage.alignmentFor(16 / 9, frame), Alignment.center);
    });

    test('unknown sizes are centred', () {
      expect(SmartFitImage.alignmentFor(0, frame), Alignment.center);
    });

    test('no blurred backdrop is drawn', () {
      final src = File('lib/widgets/smart_fit_image.dart').readAsStringSync();
      expect(src, isNot(contains('ImageFiltered')));
      expect(src, isNot(contains('BoxFit.contain')));
    });
  });
}
