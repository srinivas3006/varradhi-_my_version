import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/spotlight_item.dart';
import '../models/ad_banner.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../services/ad_delivery_service.dart';
import '../services/ad_manager.dart';
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
  final List<AdBanner> _adsPool = [];
  Map<String, dynamic>? _cachedQuote;
  Timer? _overlayTimer;
  int _requestGeneration = 0;

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
    startOverlayTimer();
    loadFeed(refresh: true);
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
  }

  void startOverlayTimer() {
    _overlayTimer?.cancel();
    _state = _state.copyWith(showOverlays: true);
    notifyListeners();

    _overlayTimer = Timer(const Duration(seconds: 4), () {
      _state = _state.copyWith(showOverlays: false);
      notifyListeners();
    });
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
    _state = _state.copyWith(showOverlays: false);
    notifyListeners();
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
    if (_state.isFetching) {
      if (!refresh) {
        await _currentFetchCompleter?.future;
        return;
      }
      await _currentFetchCompleter?.future;
    }
    if (!_state.hasMore && !refresh) return;

    final gen = refresh ? ++_requestGeneration : _requestGeneration;
    final completer = Completer<void>();
    _currentFetchCompleter = completer;

    if (refresh) {
      AdDeliveryService.instance.resetSession();
      _state = _state.copyWith(
        isFetching: true,
        errorMessage: null,
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
      final lang = AppState.instance.contentLanguage;

      // 1. Fetch ancillary items (quotes, ads, posters) asynchronously in background
      ApiService.instance.getRandomQuote(lang: lang).then((q) {
        if (q != null && (q['text'] != null || q['quote'] != null)) {
          _cachedQuote = q;
        }
      }).catchError((_) {});

      AdRepository.instance
          .getAds(
        placementZone: 'spotlight',
        scope: isLocal ? 'local' : null,
        forceRefresh: refresh,
      )
          .then((adsResp) {
        final activeAds = adsResp.data ?? [];
        for (var ad in activeAds) {
          if (!_adsPool.any((existing) => existing.id == ad.id)) {
            _adsPool.add(ad);
          }
        }
      }).catchError((_) {});

      if (_postersPool.length < 5) {
        ApiService.instance.getPosters(pageSize: 10, lang: lang).then((posters) {
          if (posters.isNotEmpty) _postersPool.addAll(posters);
        }).catchError((_) {});
      }

      // 2. Fetch primary feed from FeedRepository (shared cache + cursor pagination)
      final currentFeedState = FeedState<NewsArticle>.success(
        items: _state.feed.map((i) => i.article).whereType<NewsArticle>().toList(),
        nextCursor: _state.nextCursor,
        hasMore: _state.hasMore,
      );

      final feedState = (refresh || _state.nextCursor == null)
          ? await _feedRepository.getInitialFeed(
              pageSize: 25,
              scope: isLocal ? 'local' : null,
              category: category,
              lang: lang,
              state: isLocal ? AppState.instance.stateName : null,
              district: isLocal ? AppState.instance.district : null,
              city: isLocal ? AppState.instance.city : null,
              subdistrict: isLocal && AppState.instance.subdistrict.isNotEmpty
                  ? AppState.instance.subdistrict
                  : null,
              village: isLocal && AppState.instance.village.isNotEmpty
                  ? AppState.instance.village
                  : null,
              forceRefresh: refresh,
            )
          : await _feedRepository.loadNextPage(
              currentState: currentFeedState,
              pageSize: 25,
              scope: isLocal ? 'local' : null,
              category: category,
              lang: lang,
              state: isLocal ? AppState.instance.stateName : null,
              district: isLocal ? AppState.instance.district : null,
              city: isLocal ? AppState.instance.city : null,
              subdistrict: isLocal && AppState.instance.subdistrict.isNotEmpty
                  ? AppState.instance.subdistrict
                  : null,
              village: isLocal && AppState.instance.village.isNotEmpty
                  ? AppState.instance.village
                  : null,
            );

      // Stale request guard: if generation changed during async fetch, discard result
      if (gen != _requestGeneration) {
        debugPrint('[SpotlightController] Discarding stale response for gen $gen (current: $_requestGeneration)');
        return;
      }

      final newArticles = feedState.items;
      final updatedFeed = refresh ? <SpotlightItem>[] : List<SpotlightItem>.from(_state.feed);

      // Remove trailing shimmer card if present
      if (updatedFeed.isNotEmpty && updatedFeed.last.type == SpotlightType.shimmer) {
        updatedFeed.removeLast();
      }

      final int offset = updatedFeed.length;
      final newItems = <SpotlightItem>[];

      for (int i = 0; i < newArticles.length; i++) {
        final article = newArticles[i];

        // Map carousel vs standard
        if (article.imageUrls != null && article.imageUrls!.length > 1) {
          newItems.add(SpotlightItem.carousel(
            id: article.id,
            imageUrls: article.imageUrls!,
            title: article.title,
            baseArticle: article,
          ));
        } else {
          newItems.add(SpotlightItem.standard(article));
        }

        int count = offset + i + 1;

        // Inject poster sparingly (every 8 items) to ensure stories dominate
        if (count % 8 == 0 && _postersPool.isNotEmpty) {
          final posterData = _postersPool.removeAt(0);
          final imageUrl = posterData['image_url'] ?? posterData['imageUrl'];
          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
            newItems.add(SpotlightItem.poster(
              posterData['id'] ?? 'poster_$count',
              imageUrl.toString(),
            ));
          }
        }

        // Inject random quote at item 6 if available
        if (count == 6 && _cachedQuote != null && (_cachedQuote!['text'] != null || _cachedQuote!['quote'] != null)) {
          newItems.add(SpotlightItem.infoCard(
            _cachedQuote!['id'] ?? 'info_$count',
            (_cachedQuote!['text'] ?? _cachedQuote!['quote']).toString(),
          ));
        }
      }

      updatedFeed.addAll(newItems);
      final String? nextCursor = feedState.nextCursor;
      final bool hasMore = feedState.hasMore;

      if (updatedFeed.isNotEmpty && hasMore) {
        updatedFeed.add(SpotlightItem.shimmer());
      }

      _state = _state.copyWith(
        feed: updatedFeed,
        nextCursor: nextCursor,
        hasMore: hasMore,
        isLoading: false,
        isFetching: false,
      );

      // Trigger deferred notification permission ONLY after user sees articles
      if (updatedFeed.any((item) => item.type == SpotlightType.standard)) {
        NotificationService.instance.requestPermissionAfterArticlesLoaded();
      }
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
      _currentFetchCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
      notifyListeners();
    }
  }

  /// Evaluates user behavior and conditionally inserts an ad right after [currentIndex].
  bool evaluateAndInjectAdAfter(int currentIndex) {
    if (_adsPool.isEmpty) return false;
    final targetIndex = currentIndex + 1;

    // Boundary check
    if (targetIndex > _state.feed.length) return false;

    // Prevent duplicate ads or inserting into shimmer
    if (targetIndex < _state.feed.length) {
      final existingType = _state.feed[targetIndex].type;
      if (existingType == SpotlightType.ad || existingType == SpotlightType.shimmer) {
        return false;
      }
    }

    // Check behavior-based trigger via AdDeliveryService
    final canShow = AdDeliveryService.instance.canShowSpotlightAd(
      targetIndex: targetIndex,
      isSwipingBack: false,
    );

    if (!canShow) return false;

    final adToInsert = AdManager.instance.selectAd(_adsPool) ??
        AdDeliveryService.instance.selectAd(_adsPool);
    if (adToInsert == null) return false;

    final updated = List<SpotlightItem>.from(_state.feed);
    updated.insert(targetIndex, SpotlightItem.ad(adToInsert));
    _state = _state.copyWith(feed: updated);
    notifyListeners();

    debugPrint('[SpotlightController] Ad injected at index $targetIndex (adId: ${adToInsert.id})');
    return true;
  }

  /// Removes a completed or dismissed ad to ensure NO REPEAT on back-swipe.
  void removeAdAt(int index) {
    if (index >= 0 && index < _state.feed.length && _state.feed[index].type == SpotlightType.ad) {
      final adItem = _state.feed[index];
      if (adItem.adBanner != null) {
        AdDeliveryService.instance.markAdShown(
          adId: adItem.adBanner!.id,
          position: index,
        );
      }
      final updated = List<SpotlightItem>.from(_state.feed);
      updated.removeAt(index);
      _state = _state.copyWith(feed: updated);
      notifyListeners();
      debugPrint('[SpotlightController] Ad at $index removed to prevent repeat on back swipe.');
    }
  }

  /// Switches category filter, cancels stale requests, resets cursor, and reloads.
  Future<void> selectCategory(String? category) async {
    final trimmed = category?.trim();
    final cat = (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'all') ? null : trimmed;
    if (_state.selectedCategory == cat) return;

    HapticFeedback.selectionClick();
    ++_requestGeneration;
    _state = _state.copyWith(
      selectedCategory: cat,
      clearCategory: cat == null,
      feed: const [],
      isLoading: true,
      hasMore: true,
      nextCursor: null,
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
      nextCursor: null,
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
      nextCursor: null,
    );
    notifyListeners();
    await loadFeed(refresh: true);
  }

  /// Locates the story index for [storyId], or 0 if not found.
  int findInitialIndex(String? storyId) {
    if (storyId == null || storyId.isEmpty) return 0;
    final index = _state.feed.indexWhere((item) => item.id == storyId || (item.article?.slug == storyId));
    return index >= 0 ? index : 0;
  }

  Future<void> refreshFeed() async {
    await loadFeed(refresh: true);
  }
}
