import '../lib/spotlight/spotlight_state.dart';
import '../lib/models/redeem_request.dart';
import '../lib/core/state/feed_state.dart';
import '../lib/core/network/api_response.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
void main() {
  final loaded = FeedState<String>.success(items: ['one'], nextCursor: 'page2');
  final done = loaded.copyWith(clearCursor: true, hasMore: false);
  check(done.nextCursor == null && !done.hasMore, 'terminal cursor not cleared');
  check(done.items.single == 'one', 'terminal page lost content');
  check(loaded.toRefreshing().nextCursor == 'page2', 'refresh lost cursor');
  final failed = FeedState<String>.error(message: 'offline', previousItems: loaded.items,
      previousCursor: loaded.nextCursor, previousHasMore: true);
  check(failed.hasData && failed.hasRefreshError && failed.hasMore,
      'refresh failure lost data or retry cursor');
  final response = ApiResponse<List<String>>.fromJson({
    'data': ['one'], 'meta': {'next': 'https://example.com/feed/?cursor=abc'}, 'errors': null,
  }, (data) => List<String>.from(data));
  check(response.nextCursor == 'abc', 'pagination did not extract opaque token');
  final error = ApiResponse<List<String>>.fromJson({
    'data': null, 'meta': {}, 'errors': {'message': 'Request failed'},
  }, (data) => List<String>.from(data));
  check(error.hasErrors && error.errorMessage == 'Request failed', 'API failure swallowed');
  final spotlight = SpotlightState.initial(category: 'sports').copyWith(
      nextCursor: 'old-category-page', errorMessage: 'Offline');
  final changed = spotlight.copyWith(selectedCategory: 'politics',
      clearCursor: true, clearError: true);
  check(changed.nextCursor == null && changed.errorMessage == null,
      'Spotlight retained old category cursor or error');
  final wallet = RewardWallet.fromJson({'available_coins': 0,
      'coin_value_rupees': '1.25', 'minimum_withdrawal_coins': 250});
  check(wallet.availableCoins == 0 && wallet.coinValueRupees == 1.25 &&
      wallet.minimumWithdrawalCoins == 250, 'wallet changed server values');
  print('PASS: 8 feed, Spotlight, API pagination and wallet checks');
}
