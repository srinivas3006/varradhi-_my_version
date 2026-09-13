import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/utils/share_service.dart';

NewsArticle _article({
  String id = 'article-id',
  String slug = 'article-slug',
  String contentKind = 'article',
}) {
  return NewsArticle(
    id: id,
    title: 'News',
    slug: slug,
    summary: '',
    body: '',
    imageUrl: '',
    source: 'Vaaradhi',
    category: 'News',
    publishedAt: DateTime(2026),
    likes: 0,
    comments: 0,
    shares: 0,
    readTimeMinutes: 1,
    viewCount: 0,
    contentKind: contentKind,
  );
}

void main() {
  test('article share link uses the backend detail slug', () {
    expect(
      ShareService.buildArticleDeepLink(_article()),
      'varadhi://article/article-slug',
    );
  });

  test('UGC share link routes to the public submission', () {
    expect(
      ShareService.buildArticleDeepLink(
        _article(id: 'ugc 123', contentKind: 'ugc'),
      ),
      'varadhi://ugc/ugc%20123',
    );
  });
}
