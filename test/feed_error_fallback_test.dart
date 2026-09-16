import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/state/feed_state.dart';

void main() {
  test('failure with cached items keeps them and reports non-blocking', () {
    final s = FeedState<int>.error(
      message: 'network down',
      previousItems: const [1, 2, 3],
      previousCursor: 'cur',
    );
    expect(s.items, [1, 2, 3]);
    expect(s.status, FeedStatus.success);
    expect(s.refreshErrorMessage, 'network down');
    expect(s.errorMessage, isNull);
  });

  test('failure with nothing cached still surfaces the retry state', () {
    final s = FeedState<int>.error(message: 'network down');
    expect(s.items, isEmpty);
    expect(s.status, FeedStatus.error);
    expect(s.errorMessage, 'network down');
  });
}
