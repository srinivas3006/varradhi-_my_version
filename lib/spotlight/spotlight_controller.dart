import 'dart:async';
import '../core/ads/ad_insertion.dart';
import '../core/network/api_response.dart';
import '../repositories/ugc_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/spotlight_item.dart';
import '../models/ad_banner.dart';
import '../models/news_article.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../services/ad_delivery_service.dart';
import '../repositories/ad_repository.dart';
import '../repositories/feed_repository.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../core/errors/app_exception.dart';
import '../core/state/feed_state.dart';
import 'spotlight_state.dart';

class SpotlightController extends ChangeNotifier {
  final FeedRepository _feedRepository;
  final String? initialStoryId;

  SpotlightState _state;
  SpotlightState get state => _state;

  final List<dynamic> _postersPool = [];
  final List<Poll> _pollsPool = [];
  final List<NewsArticle> _ugcItems = [];
  String? _ugcCursor;
  bool _ugcHasMore = true;
  bool _articleHasMore = true;
  final Set<String> _dismissedSlots = {};
  final List<AdBanner> _adsPool = [];
  Timer? _overlayTimer;
  int _requestGeneration = 0;
  bool _disposed = false;
  int _paginationSequence = 0;

  // Performance caches & debouncers
  final Map<String, NewsArticle> _detailCache = {};
  DateTime? _lastPrefetchTime;
  static const Duration _prefetchDebounce = Duration(milliseconds: 600);

  NewsArticle? getCachedDetail(String key) => _detailCache[key];
  void cacheDetail(String key, NewsArticle article) {
    _detailCache[key] = article;
  }

  late String _preferencesIdentity;
  String get _currentPreferencesIdentity => [
        AppState.instance.contentLanguage,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.city,
        AppState.instance.subdistrict,
        AppState.instance.village,
      ].join('|');

  void _onPreferencesChanged() {
    final identity = _currentPreferencesIdentity;
    if (identity == _preferencesIdentity || _disposed) return;
    _preferencesIdentity = identity;
    updateLocation();
  }

  SpotlightController({
    FeedRepository? feedRepository,
    String? initialCategory,
    bool isLocal = false,
    this.initialStoryId,
  })  : _feedRepository = feedRepository ?? FeedRepository.instance,
        _state = SpotlightState.initial(
          category: initialCategory,
          locationName: AppState.instance.displayLocation,
        ).copyWith(isLocalNews: isLocal) {
    _preferencesIdentity = _currentPreferencesIdentity;
    AppState.instance.addListener(_onPreferencesChanged);
    startOverlayTimer();
    loadFeed(refresh: true);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onPreferencesChanged);
    _disposed = true;
    ++_requestGeneration;
    _overlayTimer?.cancel();
    overlayVisible.dispose();
    super.dispose();
  }

  /// How long the chrome stays up before fading.
  ///
  /// Four seconds was not enough to notice the controls and reach the ones in
  /// the far corners, so taps aimed at the + and refresh buttons landed after
  /// IgnorePointer had already engaged and did nothing at all.
  static const Duration _overlayDwell = Duration(seconds: 6);

  /// Chrome visibility, deliberately kept off [notifyListeners].
  ///
  /// The feed PageView is built inside an AnimatedBuilder on this controller,
  /// so notifying for a chrome toggle rebuilt every visible card — and since
  /// the chrome is toggled on every page change, that rebuild landed exactly
  /// as the pager was settling. That is the stutter on ad and poster pages,
  /// which are the heaviest to rebuild. A separate notifier lets the overlays
  /// repaint without touching the feed.
  final ValueNotifier<bool> overlayVisible = ValueNotifier<bool>(true);

  void _setOverlayVisible(bool visible) {
    _state = _state.copyWith(showOverlays: visible);
    overlayVisible.value = visible;
  }

  void startOverlayTimer() {
    _overlayTimer?.cancel();
    _setOverlayVisible(true);
    _overlayTimer = Timer(_overlayDwell, () => _setOverlayVisible(false));
  }

  /// Shows the chrome and leaves it up, with no hide timer running.
  ///
  /// For the utility cards (poll, poster, ad, info): their controls are the
  /// point of the card, so they must not fade out from under the reader.
  void showOverlayPersistently() {
    _overlayTimer?.cancel();
    if (_state.showOverlays) return;
    _setOverlayVisible(true);
  }

  void toggleOverlay() {
    HapticFeedback.selectionClick();
    if (_state.showOverlays) {
      hideOverlay();
    } else {
      startOverlayTimer();
    }
  }

  void hideOverlay() {
    _overlayTimer?.cancel();
    _setOverlayVisible(false);
  }

  void resetOverlayTimer() {
    startOverlayTimer();
  }

  void showOverlayWithTimer() {
    startOverlayTimer();
  }

  Completer<void>? _currentFetchCompleter;

  /// Loads feed using the unified FeedRepository data layer.
  /// Enforces request generation IDs to prevent stale or mixed-location stories.
  Future<void> loadFeed({bool refresh = false}) async {
    if (_disposed) return;
    if (_state.isFetching && !refresh) {
      await _currentFetchCompleter?.future;
      return;
    }
    if (!_state.hasMore && !refresh) return;

    final gen = refresh ? ++_requestGeneration : _requestGeneration;
    final seq = ++_paginationSequence;
    final completer = Completer<void>();
    _currentFetchCompleter = completer;

    if (refresh) {
      AdDeliveryService.instance.resetSession();
      _state = _state.copyWith(
        isFetching: true,
        clearError: true,
        generation: gen,
      );
      notifyListeners();
    } else {
      _state = _state.copyWith(isFetching: true);
      notifyListeners();
    }

    try {
      final isLocal = _state.isLocalNews;
      final category = _state.selectedCategory;
      final app = AppState.instance;
      final lang = app.contentLanguage;
      final selectedState = app.stateName;
      final district = app.district;
      final city = app.city;
      final subdistrict = isLocal ? app.subdistrict : '';
      final village = isLocal ? app.village : '';
      final scope = isLocal ? 'local' : 'main';
      final currentArticles = _state.feed
          .map((item) => item.article)
          .whereType<NewsArticle>()
          .where((article) => !article.isUgc)
          .toList();
      final current = FeedState<NewsArticle>.success(
          items: currentArticles,
          nextCursor: _state.nextCursor,
          hasMore: _articleHasMore);
      final primary = refresh
          ? _feedRepository.getInitialFeed(
              scope: scope,
              category: category,
              lang: lang,
              state: selectedState,
              district: district,
              city: city,
              subdistrict: subdistrict,
              village: village,
              pageSize: 25,
              forceRefresh: true)
          : _articleHasMore
              ? _feedRepository.loadNextPage(
                  currentState: current,
                  scope: scope,
                  category: category,
                  lang: lang,
                  state: selectedState,
                  district: district,
                  city: city,
                  subdistrict: subdistrict,
                  village: village,
                  pageSize: 25)
              : Future.value(current);
      final community = (refresh || _ugcHasMore)
          ? UgcRepository.instance
              .getUgcFeed(
                  cursor: refresh ? null : _ugcCursor,
                  scope: scope,
                  state: selectedState,
                  district: district,
                  subdistrict: subdistrict,
                  village: village)
              .catchError((Object e) =>
                  ApiResponse<List<NewsArticle>>.error(message: e.toString()))
          : Future.value(
              ApiResponse<List<NewsArticle>>.success(<NewsArticle>[]));
      final results = await Future.wait<dynamic>([
        primary,
        community,
        AdRepository.instance.getAds(
            placementZone: 'feed',
            scope: scope,
            state: selectedState,
            district: district,
            city: city,
            subdistrict: subdistrict,
            village: village,
            lang: lang,
            forceRefresh: true),
        _postersPool.isEmpty
            ? ApiService.instance.getPosters(pageSize: 10, lang: lang)
            : Future.value(List<dynamic>.from(_postersPool)),
        _pollsPool.isEmpty
            ? ApiService.instance.getPolls()
            : Future.value(List<Poll>.from(_pollsPool)),
      ]);
      if (_disposed || gen != _requestGeneration || seq != _paginationSequence)
        return;
      final feedState = results[0] as FeedState<NewsArticle>;
      final ugc = results[1] as ApiResponse<List<NewsArticle>>;
      final ads = results[2] as ApiResponse<List<AdBanner>>;
      final failure = feedState.errorMessage ?? feedState.refreshErrorMessage;
      if (refresh) {
        _ugcItems.clear();
        _dismissedSlots.clear();
      }
      if (!ugc.hasErrors) {
        final ids = _ugcItems.map((item) => item.id).toSet();
        _ugcItems.addAll((ugc.data ?? []).where((item) => ids.add(item.id)));
        _ugcCursor = ugc.nextCursor;
        _ugcHasMore = ugc.nextCursor != null;
      }
      _adsPool
        ..clear()
        ..addAll(ads.data ?? []);
      _postersPool
        ..clear()
        ..addAll(results[3] as List);
      _pollsPool
        ..clear()
        ..addAll(results[4] as List<Poll>);
      if (failure != null &&
          feedState.items.isEmpty &&
          _ugcItems.isEmpty &&
          _postersPool.isEmpty &&
          _pollsPool.isEmpty) {
        throw ApiException(failure);
      }
      _articleHasMore = feedState.hasMore;
      final seen = <String>{};
      final stories = [...feedState.items, ..._ugcItems]
          .where((item) => seen.add('${item.contentKind}:${item.id}'))
          .toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final posterIds = <String>{};
      // expand, not map: a multi-image poster becomes one page per image.
      final posters = _postersPool
          .whereType<Map>()
          .expand((json) =>
              SpotlightItem.posterPages(Map<String, dynamic>.from(json)))
          .where((item) => posterIds.add(item.id))
          .toList();
      final content = <SpotlightItem>[];
      var posterIndex = 0;
      var pollIndex = 0;
      for (var index = 0; index < stories.length; index++) {
        // Content type comes from the backend; media stays within this parent.
        content.add(SpotlightItem.standard(stories[index]));
        final position = index + 1;
        if (position % 5 == 0 && posters.isNotEmpty) {
          content.add(posters[posterIndex++ % posters.length]);
        }
        if (position % 8 == 0 && _pollsPool.isNotEmpty) {
          content.add(SpotlightItem.poll(_pollsPool[pollIndex++ % _pollsPool.length]));
        }
      }
      final run = insertAdsIntoFeed<SpotlightItem>(
        contentItems: content,
        eligibleAds: _adsPool,
        allowTimed: true,
        contentKey: (item) => '${item.type.name}:${item.id}',
      );
      final updatedFeed = run
          .where((entry) => !_dismissedSlots.contains(entry.stableKey))
          .map((entry) => entry.isAd
              ? SpotlightItem(
                  id: entry.stableKey,
                  type: SpotlightType.ad,
                  adBanner: entry.ad)
              : entry.content!)
          .toList();
      final hasMore = _articleHasMore || _ugcHasMore;
      if (updatedFeed.isNotEmpty && hasMore)
        updatedFeed.add(SpotlightItem.shimmer());
      _state = _state.copyWith(
          feed: updatedFeed,
          nextCursor: feedState.nextCursor,
          clearCursor: feedState.nextCursor == null,
          hasMore: hasMore,
          isLoading: false,
          isFetching: false,
          errorMessage: failure,
          clearError: failure == null);
      if (stories.isNotEmpty)
        NotificationService.instance.requestPermissionAfterArticlesLoaded();
    } catch (e) {
      if (gen != _requestGeneration) return;
      debugPrint('[SpotlightController] feed load error: $e');
      _state = _state.copyWith(
        isLoading: false,
        isFetching: false,
        errorMessage: e is AppException
            ? e.message
            : 'కంటెంట్ లోడ్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.',
      );
    } finally {
      if (gen == _requestGeneration) {
        _state = _state.copyWith(isFetching: false);
      }
      if (identical(_currentFetchCompleter, completer)) {
        _currentFetchCompleter = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (!_disposed) notifyListeners();
    }
  }

  /// Placement is computed from parent content, never from elapsed swipe time.
  bool evaluateAndInjectAdAfter(int currentIndex) => false;

  /// Removes a completed or dismissed ad to ensure NO REPEAT on back-swipe.
  void removeAdAt(int index) {
    if (index >= 0 &&
        index < _state.feed.length &&
        _state.feed[index].type == SpotlightType.ad) {
      _dismissedSlots.add(_state.feed[index].id);
      final updated = List<SpotlightItem>.from(_state.feed);
      updated.removeAt(index);
      _state = _state.copyWith(feed: updated);
      notifyListeners();
      debugPrint(
          '[SpotlightController] Ad at $index removed to prevent repeat on back swipe.');
    }
  }

  /// Switches category filter, cancels stale requests, resets cursor, and reloads.
  Future<void> selectCategory(String? category) async {
    final trimmed = category?.trim();
    final cat =
        (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'all')
            ? null
            : trimmed;
    if (_state.selectedCategory == cat) return;

    HapticFeedback.selectionClick();
    ++_requestGeneration;
    _state = _state.copyWith(
      selectedCategory: cat,
      clearCategory: cat == null,
      feed: const [],
      isLoading: true,
      hasMore: true,
      clearCursor: true,
    );
    notifyListeners();
    await loadFeed(refresh: true);
  }

  /// Toggles between Global and Local news feeds.
  Future<void> toggleMode(bool isLocal) async {
    if (_state.isLocalNews == isLocal) return;
    HapticFeedback.selectionClick();
    ++_requestGeneration;
    _state = _state.copyWith(
      isLocalNews: isLocal,
      locationName: AppState.instance.displayLocation,
      feed: const [],
      isLoading: true,
      hasMore: true,
      clearCursor: true,
    );
    notifyListeners();
    await loadFeed(refresh: true);
  }

  /// Refreshes feed for newly selected location, purging any stale location data.
  Future<void> updateLocation() async {
    HapticFeedback.lightImpact();
    ++_requestGeneration;
    _state = _state.copyWith(
      locationName: AppState.instance.displayLocation,
      feed: const [],
      isLoading: true,
      hasMore: true,
      clearCursor: true,
    );
    notifyListeners();
    await loadFeed(refresh: true);
  }

  /// Locates the story index for [storyId], or 0 if not found.
  int findInitialIndex(String? storyId) {
    if (storyId == null || storyId.isEmpty) return 0;
    final index = _state.feed.indexWhere(
        (item) => item.id == storyId || (item.article?.slug == storyId));
    return index >= 0 ? index : 0;
  }

  Future<void> refreshFeed() async {
    await loadFeed(refresh: true);
  }

  /// Debounced prefetch ensuring network requests are never fired in bursts on rapid flings.
  void prefetchNextPageIfNeeded(int currentIndex) {
    if (currentIndex < _state.feed.length - 6) return;
    if (_state.isFetching || !_state.hasMore) return;

    final now = DateTime.now();
    if (_lastPrefetchTime != null &&
        now.difference(_lastPrefetchTime!) < _prefetchDebounce) {
      return;
    }
    _lastPrefetchTime = now;
    loadFeed();
  }
}
