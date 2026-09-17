import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/utils/share_service.dart';

NewsArticle _article({
  String image = 'https://cdn.example.com/a.jpg',
  String kind = 'article',
}) =>
    NewsArticle.fromJson({
      'id': 'a1',
      'title': 'ఉపాధ్యాయ దినోత్సవం వేడుకలు',
      'summary': 'సారాంశం',
      'image_url': image,
      'feed_item_type': kind,
    });

void main() {
  group('Download is offered only where a poster can be built', () {
    test('an article with an image qualifies', () {
      expect(ShareService.canGeneratePoster(_article()), isTrue);
    });

    test('UGC with an image qualifies — same path as articles', () {
      final ugc = _article(kind: 'ugc');
      expect(ugc.isUgc, isTrue);
      expect(ShareService.canGeneratePoster(ugc), isTrue);
    });

    test('no image means no Download control', () {
      expect(ShareService.canGeneratePoster(_article(image: '')), isFalse);
    });

    test('a non-http image is not usable', () {
      expect(
        ShareService.canGeneratePoster(_article(image: 'file:///tmp/x.jpg')),
        isFalse,
      );
    });
  });

  group('poster generation', () {
    test('returns null rather than a poster when unsupported', () async {
      expect(await ShareService.buildPosterFile(_article(image: '')), isNull);
    });
  });

  group('the watermark cannot be omitted', () {
    final source =
        File('lib/utils/share_service.dart').readAsStringSync();
    final card =
        source.substring(source.indexOf('class _WatermarkShareCard'));

    test('the downloaded image carries no article text', () {
      // Download is the picture plus the watermark; the text travels beside
      // it in the share sheet, not burned into the pixels.
      expect(card, isNot(contains('article.title')));
      expect(card, isNot(contains('article.summary')));
    });

    test('the poster card embeds the logo asset', () {
      expect(card, contains("assets/images/logo.png"));
    });

    test('every logo in the poster is unconditional', () {
      // A watermark behind an `if` is a poster that can ship without one.
      for (final line in card.split('\n')) {
        if (line.contains('logo.png')) {
          expect(line.trimLeft().startsWith('if ('), isFalse,
              reason: 'watermark must not be conditional: $line');
        }
      }
    });

    test('the generated file is a .png', () {
      expect(source, contains("vaaradhi_poster_\$safeId.png"));
      expect(source, contains("mimeType: 'image/png'"));
    });
  });

  group('download writes to the gallery, share sends image + text', () {
    final source = File('lib/utils/share_service.dart').readAsStringSync();

    test('download saves via the gallery API, not the share sheet', () {
      final fn = source.substring(source.indexOf('static Future<int> downloadPoster'));
      final body = fn.substring(0, fn.indexOf('static Future<bool> sharePoster'));
      expect(body, contains('Gal.putImage'));
      expect(body, isNot(contains('Share.shareXFiles')),
          reason: 'Download must write to the device, not open a share sheet');
    });

    test('permission is requested only when the platform needs it', () {
      expect(source, contains('Gal.hasAccess'));
      expect(source, contains('Gal.requestAccess'));
      expect(source, contains('downloadPermissionDenied'));
    });

    test('share sends the PNG with the text alongside', () {
      final fn = source.substring(source.indexOf('static Future<bool> sharePoster'));
      expect(fn, contains("mimeType: 'image/png'"));
      expect(fn, contains('text: buildShareText(article)'));
    });
  });
}
