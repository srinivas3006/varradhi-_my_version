import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/models/unified_feed_item.dart';
import 'package:vaaradhi/spotlight/spotlight_controller.dart';

NewsArticle _a(String level, {String district = ''}) => NewsArticle.fromJson({
      'id': '$level-$district',
      'title': 't',
      'coverage_level': level,
      'district': district,
    });

bool _main(NewsArticle a) =>
    SpotlightController.belongsToTab(a, local: false, district: 'Vikarabad');
bool _local(NewsArticle a) =>
    SpotlightController.belongsToTab(a, local: true, district: 'Vikarabad');

void main() {
  group('Main: global and state news only', () {
    test('global and state stay', () {
      expect(_main(_a('global')), isTrue);
      expect(_main(_a('state', district: 'Sangareddy')), isTrue);
    });
    test('district and local stories leave Main', () {
      expect(_main(_a('district', district: 'Vikarabad')), isFalse);
      expect(_main(_a('district', district: 'Warangal')), isFalse);
      expect(_main(_a('local', district: 'Vikarabad')), isFalse);
    });
  });

  group('Local: district and village/mandal news of my district', () {
    test('my district\'s district and local stories stay', () {
      expect(_local(_a('district', district: 'Vikarabad')), isTrue);
      expect(_local(_a('local', district: 'VIKARABAD')), isTrue);
      expect(_local(_a('village', district: 'Vikarabad')), isTrue);
    });
    test('other districts and state/global leave Local', () {
      expect(_local(_a('district', district: 'Warangal')), isFalse);
      expect(_local(_a('state')), isFalse);
      expect(_local(_a('global')), isFalse);
    });
  });

  test('citizen posts: a district post is Local, a state-only post is Main',
      () {
    NewsArticle ugc(Map<String, dynamic> place) => UnifiedFeedItem.fromJson({
          'id': 'u',
          'type': 'ugc',
          'title': 't',
          ...place,
        }).toArticle();
    final district = ugc({'state': 'Telangana', 'district': 'VIKARABAD'});
    final stateOnly = ugc({'state': 'Telangana'});
    expect(_local(district), isTrue);
    expect(_main(district), isFalse);
    expect(_main(stateOnly), isTrue);
    expect(_local(stateOnly), isFalse);
  });
}
