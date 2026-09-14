import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/spotlight/spotlight_state.dart';

void main() {
  test('filter reset clears cursor and recoverable error explicitly', () {
    final previous = SpotlightState.initial(category: 'sports').copyWith(
      nextCursor: 'sports-page-2', errorMessage: 'Offline',
    );
    final next = previous.copyWith(
      selectedCategory: 'politics', clearCursor: true, clearError: true,
      hasMore: true, isLoading: true,
    );
    expect(next.nextCursor, isNull);
    expect(next.errorMessage, isNull);
    expect(next.selectedCategory, 'politics');
    expect(next.hasMore, isTrue);
    expect(previous.copyWith(showOverlays: false).nextCursor, 'sports-page-2');
  });
}
