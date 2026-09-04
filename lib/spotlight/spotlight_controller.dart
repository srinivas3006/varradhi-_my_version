import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/spotlight_item.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import 'spotlight_state.dart';

class SpotlightController extends ChangeNotifier {
  SpotlightState _state = SpotlightState.initial();
  SpotlightState get state => _state;

  final List<dynamic> _postersPool = [];
  Timer? _overlayTimer;

  SpotlightController() {
    startOverlayTimer();
    loadFeed();
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

  Future<void> loadFeed({bool refresh = false}) async {
    if (_state.isFetching) return;
    if (!_state.hasMore && !refresh) return;

    if (refresh) {
      _state = SpotlightState.initial().copyWith(
        isLocalNews: _state.isLocalNews,
        isFetching: true,
      );
      notifyListeners();
    } else {
      _state = _state.copyWith(isFetching: true);
      notifyListeners();
    }

    try {
      final isLocal = _state.isLocalNews;

      // Execute background API calls concurrently
      final feedFuture = ApiService.instance.getNewsFeed(
        cursor: _state.nextCursor,
        category: isLocal ? 'local' : null,
        scope: isLocal ? 'local' : null,
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        city: AppState.instance.city,
        latitude: AppState.instance.latitude,
        longitude: AppState.instance.longitude,
      );

      final quoteFuture = ApiService.instance.getRandomQuote();

      final adsFuture = ApiService.instance.getAds(
        zone: 'feed',
        scope: isLocal ? 'local' : 'main',
        state: isLocal ? AppState.instance.stateName : null,
        district: isLocal ? AppState.instance.district : null,
      );

      final postersFuture = _postersPool.length < 5
          ? ApiService.instance.getPosters(pageSize: 10)
          : Future.value(<dynamic>[]);

      final results = await Future.wait([
        feedFuture,
        quoteFuture,
        adsFuture,
        postersFuture,
      ]);

      final feedResponse = results[0] as dynamic;
      final quoteResponse = results[1] as dynamic;
      final adsResponse = results[2] as dynamic;
      final fetchedPosters = results[3] as List<dynamic>;

      if (fetchedPosters.isNotEmpty) {
        _postersPool.addAll(fetchedPosters);
      }

      final newArticles = (feedResponse.data as List<NewsArticle>?) ?? [];
      final activeAds = (adsResponse.data as List<dynamic>?) ?? [];

      final updatedFeed = List<SpotlightItem>.from(_state.feed);

      // Remove trailing shimmer card if present
      if (updatedFeed.isNotEmpty && updatedFeed.last.type == SpotlightType.shimmer) {
        updatedFeed.removeLast();
      }

      final int offset = updatedFeed.length;
      final newItems = <SpotlightItem>[];

      for (int i = 0; i < newArticles.length; i++) {
        newItems.add(SpotlightItem.standard(newArticles[i]));
        int count = offset + i + 1;

        // Inject poster every 4 items
        if (count % 4 == 0 && _postersPool.isNotEmpty) {
          final posterData = _postersPool.removeAt(0);
          final imageUrl = posterData['image_url'];
          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
            newItems.add(SpotlightItem.poster(
              posterData['id'] ?? 'poster_$count',
              imageUrl.toString(),
            ));
          }
        }

        // Inject random quote at item 6
        if (count == 6 && quoteResponse != null && quoteResponse['text'] != null) {
          newItems.add(SpotlightItem.infoCard(
            quoteResponse['id'] ?? 'info_$count',
            quoteResponse['text'].toString(),
          ));
        }

        // Inject ads dynamically based on display frequency
        if (activeAds.isNotEmpty) {
          for (var ad in activeAds) {
            if (ad.displayFrequency > 0 && count % ad.displayFrequency == 0) {
              newItems.add(SpotlightItem.ad(ad));
              break;
            }
          }
        }
      }

      updatedFeed.addAll(newItems);
      final String? nextCursor = feedResponse.nextCursor;
      final bool hasMore = nextCursor != null;

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
    } catch (e) {
      debugPrint('SpotlightController feed load error: $e');
      _state = _state.copyWith(
        isLoading: false,
        isFetching: false,
      );
    }

    notifyListeners();
  }

  void toggleMode(bool isLocal) {
    if (_state.isLocalNews == isLocal) return;
    HapticFeedback.selectionClick();
    _state = _state.copyWith(isLocalNews: isLocal);
    startOverlayTimer();
    loadFeed(refresh: true);
  }

  void refreshFeed() {
    loadFeed(refresh: true);
  }
}
