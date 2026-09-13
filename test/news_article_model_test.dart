import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/news_article.dart';

void main() {
  group('NewsArticle.fromJson', () {
    test('prefers full detail content from content field when present', () {
      final article = NewsArticle.fromJson({
        'id': '1',
        'title': 'Test article',
        'slug': 'test-article',
        'summary': 'Short summary',
        'content': '<p>Full article content from detail API.</p>',
        'thumbnail_url': 'https://example.com/image.jpg',
        'source_name': 'VARADHI',
        'category': 'Local',
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(article.body, '<p>Full article content from detail API.</p>');
      expect(article.summary, 'Short summary');
    });

    test('falls back to summary when detail content is missing', () {
      final article = NewsArticle.fromJson({
        'id': '2',
        'title': 'Fallback article',
        'slug': 'fallback-article',
        'summary': 'Summary only',
        'thumbnail_url': 'https://example.com/image.jpg',
        'source_name': 'VARADHI',
        'category': 'Local',
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(article.body, '');
      expect(article.summary, 'Summary only');
    });

    test(
        'detects video articles when video_url exists even without explicit media_type',
        () {
      final article = NewsArticle.fromJson({
        'id': '3',
        'title': 'Video article',
        'slug': 'video-article',
        'summary': 'Video summary',
        'thumbnail_url': 'https://example.com/poster.jpg',
        'video_url': 'https://example.com/video.mp4',
        'video_duration_seconds': 90,
        'source_name': 'VARADHI',
        'category': 'Local',
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(article.mediaType, 'video');
      expect(article.isVideo, isTrue);
      expect(article.formattedVideoDuration, '1:30');
    });

    test('preserves an explicit UGC content kind through JSON', () {
      final article = NewsArticle.fromJson({
        'id': 'ugc-1',
        'title': 'Citizen report',
        'type': 'ugc',
        'summary': 'Local update',
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(article.isUgc, isTrue);
      expect(NewsArticle.fromJson(article.toJson()).isUgc, isTrue);
    });

    test('does not classify media content_type as UGC', () {
      final article = NewsArticle.fromJson({
        'id': 'article-1',
        'title': 'Video news',
        'content_type': 'VIDEO',
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(article.isUgc, isFalse);
    });

    test('sanitizes full YouTube URL stored in youtube_video_id', () {
      final article = NewsArticle.fromJson({
        'id': 'youtube-article',
        'title': 'YouTube article',
        'youtube_video_id':
            'https://m.youtube.com/watch?v=dQw4w9WgXcQ&feature=shared',
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(
        article.videoUrl,
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(
          article.imageUrl, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
      expect(article.isVideo, isTrue);
    });

    test('builds playable media item from YouTube video id', () {
      final article = NewsArticle.fromJson({
        'id': 'media-youtube-article',
        'title': 'Media YouTube article',
        'media_items': [
          {
            'media_type': 'video',
            'youtube_video_id':
                'https://www.youtube.com/live/dQw4w9WgXcQ?si=abc',
            'is_primary': true,
          },
        ],
        'published_at': '2026-01-01T00:00:00Z',
      });

      expect(article.mediaItems.single.url,
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(
        article.mediaItems.single.thumbnailUrl,
        'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
      expect(article.mediaItems.single.isVideo, isTrue);
    });
  });
}
