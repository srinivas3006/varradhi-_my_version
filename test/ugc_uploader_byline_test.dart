import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/models/unified_feed_item.dart';

Map<String, dynamic> _ugc({Map<String, dynamic>? uploader}) => {
      'id': '7cb8',
      'type': 'ugc',
      'title': 'రూ.300 శ్రీవారి దర్శన టికెట్లు విడుదల',
      'description': 'తిరుమల',
      'source': 'USER_UPLOAD',
      'created_at': '2026-10-06T10:00:00+05:30',
      if (uploader != null) 'uploader': uploader,
    };

NewsArticle _fromFeed(Map<String, dynamic> json) =>
    UnifiedFeedItem.fromJson(json).toArticle();

void main() {
  test('the uploader name is shown, not USER_UPLOAD', () {
    final a = _fromFeed(_ugc(uploader: {
      'id': 'u1',
      'display_name': 'Ganesh Ganagani',
      'trust_level': 'VERIFIED_USER',
    }));
    expect(a.byline, 'Ganesh Ganagani');
  });

  test('an email display_name shows only the part before @', () {
    final a = _fromFeed(_ugc(uploader: {
      'display_name': 'ganaganiganesh884@gmail.com',
    }));
    expect(a.byline, 'ganaganiganesh884');
    expect(a.byline, isNot(contains('@')));
  });

  test('no uploader → nothing, never the USER_UPLOAD source code', () {
    expect(_fromFeed(_ugc()).byline, isEmpty);
  });

  test('a detail reply with an uploader map works the same', () {
    final a = NewsArticle.fromJson({
      ..._ugc(uploader: {'name': 'Ravi'}),
      'feed_item_type': 'ugc',
    });
    expect(a.byline, 'Ravi');
  });

  test('a desk article keeps its author', () {
    final a = NewsArticle.fromJson(
        {'id': 'a', 'title': 't', 'author_name': 'Sridhar'});
    expect(a.byline, 'Sridhar');
  });
}
