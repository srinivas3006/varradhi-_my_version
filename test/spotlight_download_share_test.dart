import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/utils/share_service.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

NewsArticle _story(
        {String video = '', String image = 'https://cdn.test/a.jpg'}) =>
    NewsArticle.fromJson({
      'id': 'v1',
      'title': 'శీర్షిక',
      'content': 'కథనం',
      'image_url': image,
      if (video.isNotEmpty) 'video_url': video,
      if (video.isNotEmpty) 'media_type': 'video',
      'feed_item_type': 'ugc',
      'published_at': DateTime(2026, 10, 1).toIso8601String(),
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which videos can be downloaded', () {
    test('a direct video file can', () {
      expect(
          ShareService.downloadableVideoUrl(
              _story(video: 'https://cdn.test/clip.mp4')),
          'https://cdn.test/clip.mp4');
    });

    test('YouTube and streams cannot; picture stories have none', () {
      expect(
          ShareService.downloadableVideoUrl(
              _story(video: 'https://www.youtube.com/watch?v=abc')),
          isNull);
      expect(
          ShareService.downloadableVideoUrl(
              _story(video: 'https://cdn.test/live/index.m3u8')),
          isNull);
      expect(ShareService.downloadableVideoUrl(_story()), isNull);
    });
  });

  group('Spotlight download', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppState.instance.language = 'Telugu';
    });

    testWidgets('a video story asks: image or video', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpotlightNewsCard(
            article: _story(video: 'https://cdn.test/clip.mp4'),
            onTap: () {},
            onShare: () {},
            onClose: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.download_rounded));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('download_choice_image')), findsOneWidget);
      expect(find.byKey(const Key('download_choice_video')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });

  group('share opens at once', () {
    test('the card prepares the share image in the background', () {
      final card = File('lib/widgets/spotlight/spotlight_news_card.dart')
          .readAsStringSync();
      expect(card, contains('ShareService.prepareShare(widget.article)'));
      final screen =
          File('lib/spotlight/spotlight_screen.dart').readAsStringSync();
      expect(screen, contains('ShareService.shareNow(article)'));
      expect(screen, isNot(contains('share_preparing')),
          reason: 'no "preparing" wait before the share sheet');
    });

    test('a video download never saves an unbranded file', () {
      final src = File('lib/utils/share_service.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('static Future<int> downloadVideo'));
      expect(fn.indexOf("invokeMethod<String>('watermark'"),
          lessThan(fn.indexOf('saveFileToGallery(out, isVideo: true)')));
    });
  });
}
