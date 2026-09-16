import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'app_state.dart';

/// One viewer's reaction to a piece of content.
enum Reaction { none, like, dislike }

/// Engagement counts plus this viewer's own state for one piece of content.
@immutable
class Engagement {
  const Engagement({
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.commentCount = 0,
    this.bookmarkCount = 0,
    this.reaction = Reaction.none,
    this.bookmarked = false,
  });

  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final int bookmarkCount;
  final Reaction reaction;
  final bool bookmarked;

  bool get liked => reaction == Reaction.like;
  bool get disliked => reaction == Reaction.dislike;

  Engagement copyWith({
    int? likeCount,
    int? dislikeCount,
    int? commentCount,
    int? bookmarkCount,
    Reaction? reaction,
    bool? bookmarked,
  }) {
    return Engagement(
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      commentCount: commentCount ?? this.commentCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      reaction: reaction ?? this.reaction,
      bookmarked: bookmarked ?? this.bookmarked,
    );
  }

  /// Counts never render negative, however the arithmetic lands.
  Engagement get clamped => Engagement(
        likeCount: likeCount < 0 ? 0 : likeCount,
        dislikeCount: dislikeCount < 0 ? 0 : dislikeCount,
        commentCount: commentCount < 0 ? 0 : commentCount,
        bookmarkCount: bookmarkCount < 0 ? 0 : bookmarkCount,
        reaction: reaction,
        bookmarked: bookmarked,
      );
}

/// Single source of truth for like / dislike / comment / bookmark counts.
///
/// Every surface that shows a count reads it from here, so an action taken on
/// a spotlight card is reflected on the detail screen, the feed card and the
/// bookmarks list at the same instant — no manual refresh, and no two widgets
/// disagreeing because each kept its own copy of the number.
///
/// Updates are optimistic and then reconciled: the count moves the moment the
/// reader taps, and the authoritative `like_count` / `dislike_count` the
/// reaction endpoint returns replaces the guess when it arrives. A failed call
/// rolls the entry back to exactly what it was.
///
/// Listening is per item rather than store-wide. A ChangeNotifier here would
/// rebuild every card in the feed on any tap, which is precisely the kind of
/// work that makes a vertical pager stutter.
class EngagementStore {
  EngagementStore._();

  static final EngagementStore instance = EngagementStore._();

  final Map<String, ValueNotifier<Engagement>> _entries = {};

  /// Namespaced so an article and a UGC post sharing an id cannot collide.
  static String keyFor({required String kind, required String id}) =>
      '${kind.toLowerCase()}:$id';

  /// The listenable for [key], created empty if this is its first mention.
  ValueNotifier<Engagement> listenableFor(String key) =>
      _entries.putIfAbsent(key, () => ValueNotifier<Engagement>(const Engagement()));

  Engagement stateFor(String key) => listenableFor(key).value;

  void _set(String key, Engagement next) {
    listenableFor(key).value = next.clamped;
  }

  /// Seeds counts from a feed or detail payload.
  ///
  /// Server counts win for the numbers, but the viewer's own reaction and
  /// bookmark are preserved: a feed response fetched before the reader tapped
  /// must not undo the tap.
  void seed(
    String key, {
    int? likeCount,
    int? dislikeCount,
    int? commentCount,
    int? bookmarkCount,
    Reaction? reaction,
    bool? bookmarked,
  }) {
    final current = stateFor(key);
    _set(
      key,
      current.copyWith(
        likeCount: likeCount,
        dislikeCount: dislikeCount,
        commentCount: commentCount,
        bookmarkCount: bookmarkCount,
        reaction: reaction,
        bookmarked: bookmarked,
      ),
    );
  }

  /// Applies the counts a reaction call returned.
  void applyServerCounts(String key, Map<String, dynamic> data) {
    int? read(List<String> names) {
      for (final name in names) {
        final raw = data[name];
        if (raw is num) return raw.toInt();
        if (raw is String) {
          final parsed = int.tryParse(raw);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    // The backend spells these both ways across endpoints.
    final likes = read(['like_count', 'likes_count', 'likes']);
    final dislikes = read(['dislike_count', 'dislikes_count', 'dislikes']);
    final comments = read(['comment_count', 'comments_count', 'comments']);
    if (likes == null && dislikes == null && comments == null) return;

    _set(
      key,
      stateFor(key).copyWith(
        likeCount: likes,
        dislikeCount: dislikes,
        commentCount: comments,
      ),
    );
  }

  /// Applies [next] immediately, then confirms it against the server.
  ///
  /// Rolls back to the pre-tap state if the call fails, so a count never
  /// stays wrong just because the network did.
  Future<void> setReaction(String key, String contentId, Reaction next) async {
    final before = stateFor(key);
    if (before.reaction == next) return;

    var likes = before.likeCount;
    var dislikes = before.dislikeCount;
    if (before.reaction == Reaction.like) likes -= 1;
    if (before.reaction == Reaction.dislike) dislikes -= 1;
    if (next == Reaction.like) likes += 1;
    if (next == Reaction.dislike) dislikes += 1;

    _set(
      key,
      before.copyWith(likeCount: likes, dislikeCount: dislikes, reaction: next),
    );
    AppState.instance.setLiked(contentId, next == Reaction.like);

    try {
      final data = await ApiService.instance.postArticleReaction(
        contentId,
        next == Reaction.none ? 'none' : next.name,
      );
      applyServerCounts(key, data);
    } catch (_) {
      _set(key, before);
      AppState.instance.setLiked(contentId, before.reaction == Reaction.like);
    }
  }

  /// Convenience for a like button: tapping an active like clears it.
  Future<void> toggleLike(String key, String contentId) => setReaction(
        key,
        contentId,
        stateFor(key).liked ? Reaction.none : Reaction.like,
      );

  Future<void> toggleDislike(String key, String contentId) => setReaction(
        key,
        contentId,
        stateFor(key).disliked ? Reaction.none : Reaction.dislike,
      );

  /// Bookmarks are local-first; [persist] reports whether the server agreed.
  Future<void> toggleBookmark(
    String key,
    String contentId, {
    Future<bool> Function()? persist,
  }) async {
    final before = stateFor(key);
    final next = !before.bookmarked;
    _set(
      key,
      before.copyWith(
        bookmarked: next,
        bookmarkCount: before.bookmarkCount + (next ? 1 : -1),
      ),
    );
    AppState.instance.setBookmarked(contentId, next);

    if (persist == null) return;
    try {
      if (await persist() == false) throw StateError('rejected');
    } catch (_) {
      _set(key, before);
      AppState.instance.setBookmarked(contentId, before.bookmarked);
    }
  }

  /// Called when a comment is posted or removed, so the count on every card
  /// showing this item moves without re-fetching the feed.
  void bumpCommentCount(String key, int delta) {
    _set(key, stateFor(key).copyWith(
          commentCount: stateFor(key).commentCount + delta,
        ));
  }

  @visibleForTesting
  void reset() {
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
  }
}
