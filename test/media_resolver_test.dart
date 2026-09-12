import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/media/media_resolver.dart';
import 'package:way2news_clone/core/media/media_source.dart';
import 'package:way2news_clone/models/video_item.dart';

void main() {
  group('MediaResolver Tests', () {
    test('Resolves standard YouTube watch URL correctly', () {
      final source = MediaResolver.resolve(
        youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      expect(source.type, MediaSourceType.youtube);
      expect(source.videoId, 'dQw4w9WgXcQ');
      expect(source.isShort, false);
      expect(source.isPlayable, true);
      expect(source.thumbnailUrl, contains('dQw4w9WgXcQ'));
    });

    test('Resolves YouTube Shorts URL correctly with isShort = true', () {
      final source = MediaResolver.resolve(
        youtubeUrl: 'https://www.youtube.com/shorts/abc123XYZ09',
      );

      expect(source.type, MediaSourceType.youtube);
      expect(source.videoId, 'abc123XYZ09');
      expect(source.isShort, true);
      expect(source.isPlayable, true);
    });

    test('Resolves youtu.be short link', () {
      final source = MediaResolver.resolve(
        videoUrl: 'https://youtu.be/dQw4w9WgXcQ',
      );

      expect(source.type, MediaSourceType.youtube);
      expect(source.videoId, 'dQw4w9WgXcQ');
      expect(source.isPlayable, true);
    });

    test('Resolves direct 11-character YouTube video ID', () {
      final source = MediaResolver.resolve(
        youtubeVideoId: 'dQw4w9WgXcQ',
        isShort: true,
      );

      expect(source.type, MediaSourceType.youtube);
      expect(source.videoId, 'dQw4w9WgXcQ');
      expect(source.isShort, true);
      expect(source.isPlayable, true);
    });

    test('Resolves direct MP4 video URL', () {
      final source = MediaResolver.resolve(
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      expect(source.type, MediaSourceType.networkVideo);
      expect(source.url, 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4');
      expect(source.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(source.isPlayable, true);
    });

    test('Resolves video URL with query parameters', () {
      final source = MediaResolver.resolve(
        videoUrl: 'https://cdn.example.com/media/clip.mp4?token=123&auth=abc',
      );

      expect(source.type, MediaSourceType.networkVideo);
      expect(source.isPlayable, true);
    });

    test('Resolves image-only when video is empty but thumbnail exists', () {
      final source = MediaResolver.resolve(
        videoUrl: '',
        thumbnailUrl: 'https://example.com/poster.jpg',
      );

      expect(source.type, MediaSourceType.imageOnly);
      expect(source.thumbnailUrl, 'https://example.com/poster.jpg');
      expect(source.isPlayable, false);
    });

    test('Resolves unsupported when everything is empty', () {
      final source = MediaResolver.resolve(
        videoUrl: '',
        thumbnailUrl: '',
      );

      expect(source.type, MediaSourceType.unsupported);
      expect(source.isPlayable, false);
    });

    test('extractYoutubeVideoId extracts from all standard formats', () {
      expect(MediaResolver.extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(MediaResolver.extractYoutubeVideoId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(MediaResolver.extractYoutubeVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(MediaResolver.extractYoutubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(MediaResolver.extractYoutubeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(MediaResolver.extractYoutubeVideoId('https://example.com/not-youtube'), null);
      expect(MediaResolver.extractYoutubeVideoId(null), null);
    });

    test('VideoItem.toMediaSource() properly translates to MediaSource', () {
      final item = VideoItem(
        id: 'v-101',
        title: 'Breaking News Short',
        channel: 'Vaaradhi',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        youtubeVideoId: 'dQw4w9WgXcQ',
        isShort: true,
        duration: '0:45',
        views: '1200',
        likes: 50,
      );

      final source = item.toMediaSource();
      expect(source.type, MediaSourceType.youtube);
      expect(source.videoId, 'dQw4w9WgXcQ');
      expect(source.isShort, true);
      expect(source.isPlayable, true);
    });
  });
}
