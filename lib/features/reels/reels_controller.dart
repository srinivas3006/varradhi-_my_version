import 'package:flutter/foundation.dart';

import 'reel_model.dart';
import 'reels_api.dart';

/// Reels list state: first page, cursor pagination (one request at a time,
/// deduplicated by id), the current index and the mute preference.
class ReelsController extends ChangeNotifier {
  ReelsController({
    required this.api,
    this.location = const {},
    this.scope = 'main',
    this.pageSize = 20,
    this.pinned,
  });

  final ReelsApi api;

  /// Shown first, ahead of the feed — the video a notification pointed at.
  /// Not repeated if the feed also contains it.
  final Reel? pinned;
  final Map<String, String> location;
  final String scope;
  final int pageSize;

  final List<Reel> reels = [];
  final Set<String> _ids = {};
  String? _nextUrl;

  bool isLoadingFirst = false;
  bool isLoadingMore = false;
  bool loadMoreFailed = false;
  String? firstPageError;
  int currentIndex = 0;

  /// The reader's choice, kept across swipes.
  bool isMuted = false;
  bool _disposed = false;

  bool get hasMore => _nextUrl != null;

  Future<ReelsPage> _fetchFirst() =>
      api.fetch(scope: scope, location: location, pageSize: pageSize);

  /// Returns how many new reels were added.
  int _append(List<Reel> items) {
    var added = 0;
    for (final r in items) {
      if (_ids.add(r.id)) {
        reels.add(r);
        added++;
      }
    }
    return added;
  }

  Future<void> loadFirstPage() async {
    if (isLoadingFirst) return;
    isLoadingFirst = true;
    firstPageError = null;
    _notify();
    try {
      final page = await _fetchFirst();
      reels.clear();
      _ids.clear();
      currentIndex = 0;
      if (pinned != null) _append([pinned!]);
      _append(page.items);
      _nextUrl = page.next;
    } on ReelsApiException catch (e) {
      firstPageError = e.message;
      // The feed failed, but the pointed-at video can still be watched.
      if (pinned != null && reels.isEmpty) _append([pinned!]);
    } catch (_) {
      firstPageError = 'నెట్‌వర్క్ లోపం. దయచేసి కనెక్షన్ తనిఖీ చేయండి.';
      if (pinned != null && reels.isEmpty) _append([pinned!]);
    }
    isLoadingFirst = false;
    _notify();
    if (reels.isNotEmpty && reels.length <= 3) loadMore();
  }

  Future<void> loadMore() async {
    final url = _nextUrl;
    if (url == null || isLoadingMore || isLoadingFirst) return;
    isLoadingMore = true;
    loadMoreFailed = false;
    _notify();
    var added = 0;
    try {
      final page = await api.fetch(nextUrl: url);
      added = _append(page.items);
      _nextUrl = page.next;
    } on ReelsApiException catch (e) {
      if (e.isInvalidCursor) {
        // Cursor expired: start from the first page; dedupe keeps only new.
        try {
          final page = await _fetchFirst();
          added = _append(page.items);
          _nextUrl = page.next;
        } catch (_) {
          loadMoreFailed = true;
        }
      } else {
        loadMoreFailed = true; // the reels already loaded stay
      }
    } catch (_) {
      loadMoreFailed = true;
    }
    isLoadingMore = false;
    _notify();
    // A page of nothing new: keep going while the reader is near the end —
    // unless the server handed back the same cursor, which would loop.
    if (!loadMoreFailed &&
        currentIndex >= reels.length - 3 &&
        !(added == 0 && _nextUrl == url)) {
      loadMore();
    }
  }

  void onPageChanged(int index) {
    currentIndex = index;
    _notify();
    if (index >= reels.length - 3) loadMore();
  }

  void toggleMute() {
    isMuted = !isMuted;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
