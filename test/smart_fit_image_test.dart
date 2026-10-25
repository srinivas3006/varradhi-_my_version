import 'dart:io';

import 'package:flutter/material.dart';
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

  group('loading', () {
    test('every photo of the story is a candidate, cleaned and once', () {
      expect(
        SmartFitImage.candidates('//cdn.example.com/a.jpg', [
          'https://cdn.example.com/a.jpg',
          '',
          'not a url://x',
          'https://cdn.example.com/b.jpg',
        ]),
        ['https://cdn.example.com/a.jpg', 'https://cdn.example.com/b.jpg'],
      );
    });

    test('photos are downscaled when decoded, not resized on disk', () {
      final p = SmartFitImage.providerFor('https://cdn.example.com/a.jpg');
      expect(p, isA<ResizeImage>());
      expect((p as ResizeImage).width, 1080);
      expect(p.allowUpscaling, isFalse);
    });

    testWidgets('a failing photo moves on, and ends in the error icon',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: SmartFitImage(
            imageUrl: 'https://invalid.example/a.jpg',
            fallbackUrls: ['https://invalid.example/b.jpg'],
          ),
        ),
      ));
      // Test HTTP fails every request; a stalled one times out the same way.
      for (var i = 0; i < 6; i++) {
        await tester.pump(SmartFitImage.stallTimeout);
      }
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });
}
