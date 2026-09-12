import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/models/category.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/models/poll.dart';
import 'package:way2news_clone/models/unified_feed_item.dart';

void main() {
  group('NewsArticle Model Hardening Tests', () {
    test('parses with missing optional fields without crashing', () {
      final json = {
        'id': '101',
        'title': 'Test Minimal Article',
      };

      final article = NewsArticle.fromJson(json);
      expect(article.id, '101');
      expect(article.title, 'Test Minimal Article');
      expect(article.summary, '');
      expect(article.body, '');
      expect(article.likes, 0);
      expect(article.comments, 0);
      expect(article.mediaType, 'image');
      expect(article.isVideo, isFalse);
    });

    test('safely coerces numbers that arrive as strings', () {
      final json = {
        'id': 102, // int id
        'title': 'String Numbers',
        'likes_count': '42',
        'comments_count': '7',
        'shares_count': '15',
        'read_time_minutes': '3',
        'view_count': '500',
        'video_duration_seconds': '125',
      };

      final article = NewsArticle.fromJson(json);
      expect(article.id, '102');
      expect(article.likes, 42);
      expect(article.comments, 7);
      expect(article.shares, 15);
      expect(article.readTimeMinutes, 3);
      expect(article.viewCount, 500);
      expect(article.videoDurationSeconds, 125);
    });

    test('safely parses invalid date without throwing FormatException', () {
      final json = {
        'id': '103',
        'title': 'Bad Date',
        'published_at': 'not-a-valid-date',
      };

      expect(() => NewsArticle.fromJson(json), returnsNormally);
      final article = NewsArticle.fromJson(json);
      expect(article.publishedAt, isNotNull);
    });

    test('normalizes relative thumbnail and youtube URLs', () {
      final json = {
        'id': '104',
        'title': 'URL Normalization',
        'thumbnail_url': '/media/photos/sample.jpg',
        'youtube_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      };

      final article = NewsArticle.fromJson(json);
      expect(article.imageUrl.startsWith('http'), isTrue);
      expect(article.imageUrl.contains('/media/photos/sample.jpg'), isTrue);
      expect(article.mediaType, 'video');
      expect(article.isVideo, isTrue);
    });
  });

  group('UnifiedFeedItem Model Hardening Tests', () {
    test('handles missing, null, and string-number fields safely', () {
      final json = {
        'id': 505,
        'type': 'ugc',
        'title': null,
        'summary': 'Citizen report summary',
        'thumbnail_url': '/media/ugc/thumb.jpg',
        'priority_score': '95',
        'trust_score': '88',
        'created_at': 'invalid-date',
        'metadata': null,
      };

      final item = UnifiedFeedItem.fromJson(json);
      expect(item.id, '505');
      expect(item.type, 'ugc');
      expect(item.title, '');
      expect(item.summary, 'Citizen report summary');
      expect(item.priorityScore, 95);
      expect(item.trustScore, 88);
      expect(item.thumbnailUrl.startsWith('http'), isTrue);
      expect(item.metadata, isEmpty);
      expect(item.createdAt, isNotNull);
    });
  });

  group('AdBanner Model Hardening Tests', () {
    test('handles numeric id and string frequency without casting errors', () {
      final json = {
        'id': 999, // int instead of String
        'title': 'Test Ad',
        'image_url': 'https://example.com/ad.jpg',
        'destination_url': 'https://advertiser.com',
        'display_frequency': '8',
        'ctr': '2.5',
      };

      final ad = AdBanner.fromJson(json);
      expect(ad.id, '999');
      expect(ad.displayFrequency, 8);
      expect(ad.ctr, 2.5);
    });
  });

  group('Category Model Hardening Tests', () {
    test('safely parses order as string and is_active as integer', () {
      final json = {
        'id': 1,
        'name': 'రాజకీయాలు',
        'slug': 'politics',
        'order': '10',
        'is_active': 1,
      };

      final cat = Category.fromJson(json);
      expect(cat.id, '1');
      expect(cat.name, 'రాజకీయాలు');
      expect(cat.order, 10);
      expect(cat.isActive, isTrue);
    });
  });

  group('Poll Model Hardening Tests', () {
    test('safely parses votes, percentages, and dates with unexpected types', () {
      final json = {
        'id': 12,
        'question': 'మీ అభిప్రాయం ఏమిటి?',
        'option_a': 'అవును',
        'option_b': 'కాదు',
        'vote_a_count': '150',
        'vote_b_count': '50',
        'percentages': {'a': '75.0', 'b': '25.0'},
        'total_votes': '200',
        'ends_at': '2026-12-31T23:59:59Z',
      };

      final poll = Poll.fromJson(json);
      expect(poll.id, '12');
      expect(poll.question, 'మీ అభిప్రాయం ఏమిటి?');
      expect(poll.totalVotes, 200);
      expect(poll.votes[0], 150);
      expect(poll.votes[1], 50);
      expect(poll.percentFor(0), 0.75);
      expect(poll.endsAt?.year, 2026);
    });
  });
}
