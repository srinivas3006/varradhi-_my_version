import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/live_news.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/screens/news_feed_tab.dart';

void main() {
  group('Hero Breaking and Live Stream Card Tests', () {
    final mockActiveLive = LiveNews(
      id: 'live-1',
      title: 'Breaking: Telangana Assembly Live Discussion',
      channelName: 'Vaaradhi TV',
      youtubeUrl: 'https://youtube.com/watch?v=live123',
      youtubeVideoId: 'live123',
      thumbnailUrl: 'https://example.com/live_thumb.jpg',
      description: 'Live coverage from assembly',
      isActive: true,
      autoplay: false,
      sortOrder: 1,
      status: 'live',
    );

    final mockInactiveLive = LiveNews(
      id: 'live-2',
      title: 'Past Bulletin',
      channelName: 'Vaaradhi TV',
      youtubeUrl: 'https://youtube.com/watch?v=past123',
      youtubeVideoId: 'past123',
      thumbnailUrl: 'https://example.com/past_thumb.jpg',
      description: 'Past bulletin',
      isActive: false,
      autoplay: false,
      sortOrder: 2,
      status: 'ended',
    );

    final mockArticle1 = NewsArticle(
      id: 'art-1',
      title: 'గణేష్ నిమజ్జనం ప్రశాంతంగా నిర్వహించాలి',
      summary: 'Summary 1',
      body: 'Body 1',
      imageUrl: 'https://example.com/art1.jpg',
      source: 'Vaaradhi',
      category: 'General',
      publishedAt: DateTime.now(),
      likes: 10,
      dislikes: 1,
      comments: 5,
      shares: 2,
      readTimeMinutes: 3,
      viewCount: 120,
      coverageLevel: 'district',
      authorName: 'Reporter',
      language: 'te',
      isBreaking: true,
      mediaItems: [],
    );

    final mockArticle2 = NewsArticle(
      id: 'art-2',
      title: 'తెలంగాణకు నిజమైన స్వాతంత్య్రం',
      summary: 'Summary 2',
      body: 'Body 2',
      imageUrl: 'https://example.com/art2.jpg',
      source: 'Vaaradhi',
      category: 'Politics',
      publishedAt: DateTime.now(),
      likes: 20,
      dislikes: 0,
      comments: 8,
      shares: 4,
      readTimeMinutes: 2,
      viewCount: 250,
      coverageLevel: 'state',
      authorName: 'Reporter',
      language: 'te',
      isBreaking: true,
      mediaItems: [],
    );

    test('HeroCardItem correctly differentiates live and article items', () {
      final liveItem = HeroCardItem.live(mockActiveLive);
      expect(liveItem.kind, equals(HeroCardKind.liveStream));
      expect(liveItem.liveStream, isNotNull);
      expect(liveItem.liveStream?.title, contains('Telangana Assembly'));
      expect(liveItem.article, isNull);

      final articleItem = HeroCardItem.article(mockArticle1);
      expect(articleItem.kind, equals(HeroCardKind.breakingArticle));
      expect(articleItem.article, isNotNull);
      expect(articleItem.article?.title, contains('గణేష్ నిమజ్జనం'));
      expect(articleItem.liveStream, isNull);
    });

    test('Active live streams precede breaking articles in hero cards', () {
      final liveNewsList = [mockActiveLive, mockInactiveLive];
      final breakingArticles = [mockArticle1, mockArticle2];

      final activeStreams = liveNewsList.where((s) => s.isLiveActive).toList();
      final heroItems = [
        ...activeStreams.map((s) => HeroCardItem.live(s)),
        ...breakingArticles.map((a) => HeroCardItem.article(a)),
      ];

      expect(heroItems.length, equals(3));
      // First card MUST be the live stream
      expect(heroItems[0].kind, equals(HeroCardKind.liveStream));
      expect(heroItems[0].liveStream?.id, equals('live-1'));

      // Subsequent cards are breaking articles (NO live status)
      expect(heroItems[1].kind, equals(HeroCardKind.breakingArticle));
      expect(heroItems[1].article?.id, equals('art-1'));
      expect(heroItems[2].kind, equals(HeroCardKind.breakingArticle));
      expect(heroItems[2].article?.id, equals('art-2'));
    });

    test('When no active live streams exist, hero cards contain only breaking articles', () {
      final liveNewsList = [mockInactiveLive];
      final breakingArticles = [mockArticle1, mockArticle2];

      final activeStreams = liveNewsList.where((s) => s.isLiveActive).toList();
      final heroItems = [
        ...activeStreams.map((s) => HeroCardItem.live(s)),
        ...breakingArticles.map((a) => HeroCardItem.article(a)),
      ];

      expect(heroItems.length, equals(2));
      expect(heroItems.every((item) => item.kind == HeroCardKind.breakingArticle), isTrue);
      expect(heroItems.any((item) => item.kind == HeroCardKind.liveStream), isFalse);
    });

    test('When both live streams and articles are empty, hero cards are empty', () {
      final List<LiveNews> liveNewsList = [];
      final List<NewsArticle> breakingArticles = [];

      final activeStreams = liveNewsList.where((s) => s.isLiveActive).toList();
      final heroItems = [
        ...activeStreams.map((s) => HeroCardItem.live(s)),
        ...breakingArticles.map((a) => HeroCardItem.article(a)),
      ];

      expect(heroItems.isEmpty, isTrue);
    });
  });
}
