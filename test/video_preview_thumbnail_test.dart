import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/widgets/news_article_video_player.dart';

void main() {
  group('Video Preview Thumbnail Resolution Tests', () {
    test('MediaItem.fromJson resolves YouTube thumbnail when url is YouTube link', () {
      final item = MediaItem.fromJson({
        'media_type': 'video',
        'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      });

      expect(item.isVideo, isTrue);
      expect(item.thumbnailUrl, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('NewsArticle.fromJson resolves YouTube thumbnail for video without explicit thumbnail_url', () {
      final article = NewsArticle.fromJson({
        'id': 'v1',
        'title': 'YouTube Video Story',
        'video_url': 'https://youtu.be/dQw4w9WgXcQ',
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(article.isVideo, isTrue);
      expect(article.imageUrl, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('NewsArticle.orderedMedia enriches video items missing thumbnails with fallback', () {
      final article = NewsArticle.fromJson({
        'id': 'v2',
        'title': 'Story with media items',
        'image_url': 'https://example.com/fallback.jpg',
        'media_items': [
          {
            'media_type': 'video',
            'url': 'https://example.com/video.mp4',
            'thumbnail_url': '',
          }
        ],
        'published_at': '2026-01-01T00:00:00Z',
      });

      final ordered = article.orderedMedia;
      expect(ordered.length, 1);
      expect(ordered.first.isVideo, isTrue);
      expect(ordered.first.thumbnailUrl, 'https://example.com/fallback.jpg');
    });
  });

  group('NewsArticleVideoPlayer Lazy Loading & Thumbnail UI Tests', () {
    testWidgets('Renders thumbnail initially with play button and does NOT load video player until tapped', (tester) async {
      final article = NewsArticle.fromJson({
        'id': 'v3',
        'title': 'Lazy Load Video Story',
        'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        'video_duration_seconds': 120,
        'published_at': '2026-01-01T00:00:00Z',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewsArticleVideoPlayer(
              article: article,
              height: 250,
            ),
          ),
        ),
      );

      // Play button symbol is displayed
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Duration badge is displayed
      expect(find.text('2:00'), findsOneWidget);

      // Verify VideoPlayerScreen or active player controls are NOT mounted initially
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('Tapping thumbnail initiates playback state', (tester) async {
      final article = NewsArticle.fromJson({
        'id': 'v4',
        'title': 'Tap to Play Story',
        'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        'published_at': '2026-01-01T00:00:00Z',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewsArticleVideoPlayer(
              article: article,
              height: 250,
            ),
          ),
        ),
      );

      // Tap on the play button / thumbnail
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      // Top action close button appears during playback mode
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
