import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/utils/share_service.dart';

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
    // The watermark now lives in its own widget, which both the share card
    // and the download poster render. The guard follows it there.
    final card =
        File('lib/widgets/watermark/article_watermark_overlay.dart')
            .readAsStringSync();

    test('the floating overlay carries no article text', () {
      expect(card, isNot(contains('article.title')));
      expect(card, isNot(contains('article.summary')));
    });

    test('the shared image is the 1600x1200 news card', () {
      // Category, date, headline and photo come from the article; the
      // black logo strip is always drawn.
      expect(source, contains('NewsShareCard('));
      expect(source, contains('headline: article.title.trim()'));
      expect(source, contains('meta: shareMeta(article)'));
      final card =
          File('lib/widgets/sharing/news_share_card.dart').readAsStringSync();
      // Drawn on both the landscape (Share) and portrait (Download) card,
      // never behind a condition.
      expect(
          RegExp(r'^\s*_BrandStrip\(', multiLine: true).hasMatch(card), isTrue);
      expect(RegExp(r'if \([^)]*\)\s*_BrandStrip\(').hasMatch(card), isFalse);
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

    test('the share card renders the masthead band', () {
      // The floating overlay was removed from every banner surface — the
      // band is the watermark now.
      expect(source, contains('WatermarkBanner('));
      expect(source, isNot(contains('ArticleWatermarkOverlay')));
    });

    test('the generated file is a .jpg', () {
      // The news card is vaaradhi_<id>.jpg; the admin brand stamp writes
      // <name>.jpg through the shared composer.
      // vaaradhi_<id>.jpg (share) / vaaradhi_<id>_dl.jpg (download).
      expect(source, contains("vaaradhi_\$safeId"));
      expect(source, contains("_dl' : ''}.jpg"));
      expect(source, contains("/\$fileName.jpg"));
      expect(source, contains("mimeType: 'image/jpeg'"));
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

    test('share sends the JPEG with the text alongside', () {
      final fn = source.substring(source.indexOf('static Future<bool> sharePoster'));
      expect(fn, contains("mimeType: 'image/jpeg'"));
      expect(fn, contains('final shareText = buildShareText(article);'));
      expect(fn, contains('text: shareText'));
    });
  });
  group('Download and Share use the same design', () {
    final source = File('lib/utils/share_service.dart').readAsStringSync();

    test('Download adds the start of the story', () {
      final fn = source
          .substring(source.indexOf('static Future<int> downloadPoster'));
      expect(fn.substring(0, 400), contains('buildDownloadFile(article)'));
      expect(source,
          contains('generateArticleImage(article, forDownload: true)'));
      expect(source,
          contains("summary: forDownload ? shareSummary(source) : ''"));
    });

    test('Share uses the card without story text', () {
      final fn = source
          .substring(source.indexOf('static Future<File?> buildPosterFile'));
      expect(fn.substring(0, 400), contains('generateArticleImage(article)'));
      expect(fn.substring(0, 400), isNot(contains('forDownload: true')));
    });

    test('there is one card design, no red-banner card', () {
      expect(source, isNot(contains('NewsDownloadCard')));
      expect(File('lib/widgets/sharing/news_download_card.dart').existsSync(),
          isFalse);
    });
  });
}

