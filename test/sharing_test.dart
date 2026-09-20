import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/models/video_item.dart';
import 'package:way2news_clone/services/sharing/share_brand_config.dart';
import 'package:way2news_clone/services/sharing/share_content_builder.dart';
import 'package:way2news_clone/services/sharing/share_models.dart';
import 'package:way2news_clone/services/sharing/share_text_builder.dart';

void main() {
  group('canonical URLs use the public site, never the API host', () {
    test('each type gets its own route', () {
      const cases = {
        ShareContentType.article: 'article',
        ShareContentType.poster: 'poster',
        ShareContentType.poll: 'poll',
        ShareContentType.ugc: 'ugc',
        ShareContentType.video: 'video',
        ShareContentType.short: 'short',
      };
      cases.forEach((type, route) {
        // Trailing slash is part of the backend route contract.
        expect(ShareContentBuilder.canonicalUrl(type, 'abc'),
            'https://vaaradhinews.com/$route/abc/');
      });
    });

    test('identifiers are percent-encoded', () {
      expect(
        ShareContentBuilder.canonicalUrl(ShareContentType.article, 'a b/c'),
        contains('a%20b%2Fc'),
      );
    });

    test('a missing identifier yields no URL at all', () {
      // Better nothing than a link that cannot resolve.
      expect(ShareContentBuilder.canonicalUrl(ShareContentType.poster, ''),
          isNull);
      expect(ShareContentBuilder.canonicalUrl(ShareContentType.article, '  '),
          isNull);
    });

    test('the API host is never used for sharing', () {
      final url = ShareContentBuilder.canonicalUrl(
          ShareContentType.article, 'x')!;
      expect(url, isNot(contains('api.')));
      expect(url, startsWith('https://'));
    });
  });

  group('builders produce one shape from every model', () {
    test('an article', () {
      final c = ShareContentBuilder.fromArticle(NewsArticle.fromJson({
        'id': '1',
        'slug': 'my-story',
        'title': 'Headline',
        'summary': 'Summary',
        'image_url': 'https://cdn.x/a.jpg',
      }));
      expect(c.contentType, ShareContentType.article);
      expect(c.canonicalUrl, endsWith('/article/my-story/'));
      expect(c.hasImage, isTrue);
      expect(c.templateVersion, 'article_v1');
    });

    test('a UGC post routes to /ugc/', () {
      final c = ShareContentBuilder.fromUgc(NewsArticle.fromJson({
        'id': '9',
        'title': 'Report',
        'feed_item_type': 'ugc',
      }));
      expect(c.contentType, ShareContentType.ugc);
      expect(c.canonicalUrl, contains('/ugc/'));
    });

    test('a Short routes to /short/, a video to /video/', () {
      final short = ShareContentBuilder.fromShort(VideoItem.fromJson(
          {'id': 's1', 'title': 'S', 'is_short': true, 'thumbnail_url': ''}));
      final video = ShareContentBuilder.fromVideo(VideoItem.fromJson(
          {'id': 'v1', 'title': 'V', 'thumbnail_url': ''}));
      expect(short.canonicalUrl, endsWith('/short/s1/'));
      expect(video.canonicalUrl, endsWith('/video/v1/'));
      expect(short.templateVersion, 'short_v1');
    });

    test('a poll', () {
      final c = ShareContentBuilder.fromPoll(id: 'p1', question: 'Who?');
      expect(c.contentType, ShareContentType.poll);
      expect(c.canonicalUrl, endsWith('/poll/p1/'));
    });

    test('a poster', () {
      final c = ShareContentBuilder.fromPoster(
          {'id': 'g1', 'title': 'Greeting', 'image_url': 'https://cdn.x/p.jpg'});
      expect(c.canonicalUrl, endsWith('/poster/g1/'));
      expect(c.hasImage, isTrue);
    });
  });

  group('share text', () {
    ShareContent make(ShareContentType t) => ShareContent(
          contentType: t,
          contentId: '1',
          title: 'తెలుగు వార్త Headline',
          canonicalUrl: ShareContentBuilder.canonicalUrl(t, '1'),
        );

    test('a link share carries title and the canonical public URL', () {
      final text = ShareTextBuilder.forContent(make(ShareContentType.article));
      expect(text, contains('తెలుగు వార్త Headline'));
      expect(text, contains('https://vaaradhinews.com/article/1/'));
      expect(text, contains('Read on Vaaradhi News:'));
    });

    test('each type gets its own lead-in', () {
      const leads = {
        ShareContentType.poll: 'Vote on Vaaradhi News:',
        ShareContentType.video: 'Watch on Vaaradhi News:',
        ShareContentType.poster: 'Shared from Vaaradhi News:',
        ShareContentType.ugc: 'Community news on Vaaradhi News:',
      };
      leads.forEach((type, lead) {
        expect(ShareTextBuilder.forContent(make(type)), contains(lead));
      });
    });

    test('a media share is marked and still carries the link', () {
      final text = ShareTextBuilder.forMedia(
          make(ShareContentType.video), ShareFormat.video);
      expect(text, startsWith('[VIDEO]'));
      expect(text, contains('https://vaaradhinews.com/video/1/'));
    });

    test('mixed Telugu and English survives intact', () {
      final text = ShareTextBuilder.forContent(make(ShareContentType.article));
      expect(text, contains('తెలుగు'));
      expect(text, contains('Headline'));
    });
  });

  group('nothing internal or private leaks', () {
    test('share text contains no API host, token or file uri', () {
      final c = ShareContentBuilder.fromArticle(NewsArticle.fromJson({
        'id': '1',
        'slug': 'a-story',
        'title': 'T',
        // Even when the image lives on the API host, the shared text must
        // carry only the public page URL.
        'image_url': 'https://api.vaaradhinews.com/internal/a.jpg',
      }));
      final text = ShareTextBuilder.forContent(c);
      expect(text, isNot(contains('api.vaaradhinews.com')));
      expect(text, isNot(contains('file://')));
      expect(text, isNot(contains('token')));
      expect(text, isNot(contains('Bearer')));
      expect(text, contains('https://vaaradhinews.com/article/'));
    });

    test('a non-public item exposes no share URL path', () {
      const c = ShareContent(
        contentType: ShareContentType.ugc,
        contentId: 'x',
        title: 'private',
        isPublic: false,
      );
      expect(c.isShareable, isFalse,
          reason: 'private items must not produce a shareable link');
    });
  });

  group('the sheet offers only formats the item has', () {
    test('text-only content offers link alone', () {
      const c = ShareContent(
        contentType: ShareContentType.article,
        contentId: '1',
        title: 'T',
        canonicalUrl: 'https://vaaradhinews.com/article/1',
      );
      expect(c.availableFormats, [ShareFormat.link]);
    });

    test('an item with an image adds image', () {
      const c = ShareContent(
        contentType: ShareContentType.article,
        contentId: '1',
        title: 'T',
        canonicalUrl: 'https://vaaradhinews.com/article/1',
        imageUrl: 'https://cdn.x/a.jpg',
      );
      expect(c.availableFormats, contains(ShareFormat.image));
      expect(c.availableFormats, isNot(contains(ShareFormat.video)));
    });

    test('a video adds video', () {
      const c = ShareContent(
        contentType: ShareContentType.video,
        contentId: '1',
        title: 'T',
        canonicalUrl: 'https://vaaradhinews.com/video/1',
        videoUrl: 'https://cdn.x/v.mp4',
      );
      expect(c.availableFormats, contains(ShareFormat.video));
    });
  });

  group('migrated call sites no longer share raw URLs', () {
    test('poster card and detail go through the sheet', () {
      for (final path in [
        'lib/widgets/poster_card.dart',
        'lib/screens/poster_detail_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        // Comments may mention the old call; only executable lines count.
        final code = src
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(code, contains('ShareSheet.show'), reason: path);
        expect(code, isNot(contains('Share.share(')), reason: path);
        expect(code, isNot(contains('Share.shareXFiles(')), reason: path);
      }
    });
  });

  group('an article shares its slug, never its UUID', () {
    test('the public page is keyed on the slug', () {
      final c = ShareContentBuilder.fromArticle(NewsArticle.fromJson({
        'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'slug': 'telangana-local-story',
        'title': 'T',
      }));
      expect(c.canonicalUrl, endsWith('/article/telangana-local-story/'));
      expect(c.canonicalUrl, isNot(contains('3fa85f64')),
          reason: 'a UUID on the article route is a guaranteed 404');
    });

    test('an article with no slug is not shareable', () {
      final c = ShareContentBuilder.fromArticle(
          NewsArticle.fromJson({'id': 'uuid-only', 'title': 'T'}));
      expect(c.isShareable, isFalse);
    });

    test('UGC is keyed on its submission id, not a slug', () {
      final c = ShareContentBuilder.fromArticle(NewsArticle.fromJson({
        'id': 'sub-123',
        'slug': 'ignored',
        'title': 'T',
        'feed_item_type': 'ugc',
      }));
      expect(c.canonicalUrl, endsWith('/ugc/sub-123/'));
    });
  });

  group('App Links are declared for every shareable route', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('autoVerify is set for the public host', () {
      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android:host="vaaradhinews.com"'));
    });

    for (final route in ['article', 'poster', 'poll', 'ugc', 'video', 'short']) {
      test('/$route/ is declared', () {
        expect(manifest, contains('android:pathPrefix="/$route/"'));
      });
    }

    test('assetlinks.json is valid and names the release package', () {
      final f = File('web/.well-known/assetlinks.json');
      expect(f.existsSync(), isTrue);
      final json = jsonDecode(f.readAsStringSync()) as List;
      final target = (json.first as Map)['target'] as Map;
      expect(target['package_name'], 'com.varadhi');
      expect((target['sha256_cert_fingerprints'] as List), isNotEmpty);
    });
  });
}
