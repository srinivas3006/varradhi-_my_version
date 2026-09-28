import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState.instance;
    state.blockedUserIds.clear();
    state.articleComments.clear();
  });

  test('blockUser adds userId, persists, and isUserBlocked returns true', () async {
    final state = AppState.instance;
    expect(state.isUserBlocked('user_123'), isFalse);

    await state.blockUser('user_123');
    expect(state.isUserBlocked('user_123'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('blockedUserIds'), contains('user_123'));

    await state.unblockUser('user_123');
    expect(state.isUserBlocked('user_123'), isFalse);
  });

  test('getComments filters out comments and replies from blocked users', () {
    final state = AppState.instance;
    final comment1 = Comment(
      id: 'c1',
      authorId: 'user_good',
      username: 'GoodUser',
      avatarUrl: '',
      text: 'Hello world',
      postedAt: DateTime.now(),
    );
    final comment2 = Comment(
      id: 'c2',
      authorId: 'user_bad',
      username: 'BadUser',
      avatarUrl: '',
      text: 'Spam text',
      postedAt: DateTime.now(),
    );
    final replyToGood = Comment(
      id: 'r1',
      authorId: 'user_bad',
      username: 'BadUser',
      avatarUrl: '',
      text: 'Spam reply',
      postedAt: DateTime.now(),
    );
    comment1.replies.add(replyToGood);

    state.articleComments['art_1'] = [comment1, comment2];

    // Before blocking: both comments returned
    expect(state.getComments('art_1').length, equals(2));

    // After blocking user_bad: comment2 and reply r1 are filtered out
    state.blockedUserIds.add('user_bad');
    final filtered = state.getComments('art_1');
    expect(filtered.length, equals(1));
    expect(filtered.first.id, equals('c1'));
    expect(filtered.first.replies, isEmpty);
  });
}
