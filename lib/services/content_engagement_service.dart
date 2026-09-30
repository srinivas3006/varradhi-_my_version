import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/news_article.dart';
import '../state/app_state.dart';
import 'api_service.dart';
import 'dio_client.dart';

/// Endpoints for engagement on citizen (UGC) posts and for reporting desk
/// articles — implemented by the backend (frontend_handover_latest.md §17).
class EngagementEndpoints {
  EngagementEndpoints._();

  /// PUT {reaction_type: like|dislike} / DELETE — same shape as articles.
  static String ugcReaction(String submissionId) =>
      '/api/v1/ugc/$submissionId/reaction/';

  /// POST → {bookmarked: bool}
  static String ugcBookmarkToggle(String submissionId) =>
      '/api/v1/ugc/$submissionId/bookmark/toggle/';

  /// POST {reason, notes}
  static String articleReport(String articleId) =>
      '/api/v1/articles/$articleId/report/';

  /// Existing, documented.
  static const String ugcReport = '/api/v1/ugc/report/';
}

enum ReportOutcome {
  sent,
  alreadyReported,

  /// No report endpoint for this story type yet; caller uses the fallback.
  unsupported,
  failed,
}

/// One entry point for Like / Dislike / Save / Report on any story, desk
/// article or citizen post. Callers never branch on the story type.
///
/// Real failures (network, 404 not found, 429 throttled, 5xx) surface so the
/// UI can roll back. Only a server without the route (405/501, i.e. an older
/// deployment) makes likes/saves stay on the device and desk reports fall
/// back to email.
class ContentEngagementService {
  ContentEngagementService._({Dio? dio}) : _dioOverride = dio;
  static final ContentEngagementService instance = ContentEngagementService._();

  @visibleForTesting
  factory ContentEngagementService.forTesting(Dio dio) =>
      ContentEngagementService._(dio: dio);

  final Dio? _dioOverride;
  Dio get _dio => _dioOverride ?? DioClient().dio;

  /// Capabilities the backend has told us it does not have (this session).
  final Set<String> _unsupported = {};

  static const _kUgcReaction = 'ugc_reaction';
  static const _kArticleReport = 'article_report';

  /// Only "route/method not available" counts as unsupported. The endpoints
  /// are live (handover §17), so a 404 means the *item* is missing or not
  /// public ("Submission not found." / "Article not found.") and is a real
  /// failure the UI must show, not a reason to fall back.
  static bool _isUnsupported(Object e) {
    if (e is! DioException) return false;
    final code = e.response?.statusCode;
    return code == 405 || code == 501;
  }

  static String _idOf(NewsArticle a) => a.id.isNotEmpty ? a.id : a.slug;

  static Map<String, dynamic> _data(Response r) {
    final body = r.data;
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return body is Map ? Map<String, dynamic>.from(body) : {};
  }

  // --- Like / Dislike -----------------------------------------------------

  /// [reaction] is `like`, `dislike` or `none`. Returns the server's counts
  /// when it has them, or an empty map when the reaction is device-only.
  /// Throws only on a real failure (network, 5xx), so callers can roll back.
  Future<Map<String, dynamic>> react(NewsArticle story, String reaction) async {
    final id = _idOf(story);
    if (!story.isUgc) {
      return ApiService.instance.postArticleReaction(id, reaction);
    }
    if (_unsupported.contains(_kUgcReaction)) return const {};
    try {
      final path = EngagementEndpoints.ugcReaction(id);
      final r = reaction == 'none'
          ? await _dio.delete(path)
          : await _dio.put(path, data: {'reaction_type': reaction});
      return _data(r);
    } catch (e) {
      if (_isUnsupported(e)) {
        _unsupported.add(_kUgcReaction);
        return const {}; // kept locally via AppState.setReaction
      }
      rethrow;
    }
  }

  // --- Bookmark -----------------------------------------------------------
  //
  // "Bookmark" is the backend's name for saving a story, and the only one the
  // app uses for it (bookmark handover):
  //   save article:    POST /api/v1/bookmarks/          {article_id}  §3
  //   unsave article:  POST /api/v1/bookmarks/toggle/   {article_id}  §2
  //   citizen post:    POST /api/v1/ugc/{id}/bookmark/toggle/         §4
  // Toggles answer {bookmarked: bool}, which is the final state.

  /// Moves the story's bookmark to [nowBookmarked] and returns the state the
  /// server reports afterwards, or null on failure (the caller restores the
  /// previous icon).
  ///
  /// Nothing here is retried after a failure: a timed-out toggle may still
  /// have gone through, and repeating it would reverse the bookmark.
  Future<bool?> setBookmarked(NewsArticle story,
      {required bool nowBookmarked}) async {
    final id = _idOf(story);
    if (id.isEmpty) {
      debugPrint('[Bookmark] no id on story; nothing sent');
      return null;
    }
    debugPrint('[Bookmark] ${story.isUgc ? 'ugc' : 'article'} $id '
        '-> want bookmarked=$nowBookmarked');

    if (!AppState.instance.isLoggedIn) {
      // Guests bookmark too, like Way2News: the story is kept on the phone
      // and copied to the account when they log in (syncGuestBookmarks).
      // The server has no guest bookmarks, so nothing is sent now.
      if (nowBookmarked) {
        await AppState.instance.saveStoryOnDevice(story);
      } else {
        await AppState.instance.removeDeviceSavedStory(id);
        AppState.instance.setBookmarked(id, false);
      }
      debugPrint('[Bookmark] guest: $id kept on the phone '
          'bookmarked=$nowBookmarked');
      return nowBookmarked;
    }

    try {
      final bookmarked = story.isUgc
          ? await _toggleUgc(id)
          : await _setArticle(id, nowBookmarked);
      debugPrint('[Bookmark] ${story.isUgc ? 'ugc' : 'article'} $id '
          'now bookmarked=$bookmarked');
      return bookmarked;
    } catch (e) {
      debugPrint('[Bookmark] ${story.isUgc ? 'ugc' : 'article'} $id '
          'failed: ${_message(e)}');
      return null;
    }
  }

  Future<bool> _setArticle(String id, bool nowBookmarked) async {
    if (nowBookmarked) {
      // Save only — this endpoint can never remove a bookmark, so a stale
      // app copy cannot turn a save into an unsave.
      await ApiService.instance.addBookmark(id);
      return true;
    }
    final bookmarked = await ApiService.instance.toggleBookmark(id);
    if (bookmarked == true) {
      // It was not bookmarked on the server, so this toggle added it. Toggle
      // back so the server ends where the reader tapped. This is a reply to
      // a successful answer, not a retry of a failed request.
      debugPrint('[Bookmark] article $id was not bookmarked on the server; '
          'toggling back');
      return await ApiService.instance.toggleBookmark(id) ?? false;
    }
    return bookmarked ?? false;
  }

  Future<bool> _toggleUgc(String id) async {
    final r = await _dio.post(EngagementEndpoints.ugcBookmarkToggle(id));
    final value = _data(r)['bookmarked'];
    debugPrint('[Bookmark] POST ${EngagementEndpoints.ugcBookmarkToggle(id)} '
        '-> ${r.statusCode} bookmarked=$value');
    if (value is! bool) throw Exception('no bookmarked in response');
    // A logged-in bookmark lives on the server; drop any phone copy.
    if (!value) await AppState.instance.removeDeviceSavedStory(id);
    return value;
  }

  Future<void>? _guestSync;

  /// Copies the bookmarks a guest made on this phone into the account that
  /// just logged in, then clears them from the phone. Runs once per login
  /// and again whenever the Saved screen opens while any are left (e.g. the
  /// network was down at login).
  ///
  /// Checks the account's saved list first so nothing is toggled off: an
  /// article is added with the safe POST /bookmarks/, and a citizen post is
  /// toggled only when the account does not have it yet. A story that fails
  /// stays on the phone for the next attempt.
  Future<void> syncGuestBookmarks() =>
      _guestSync ??= _syncGuestBookmarks().whenComplete(() => _guestSync = null);

  Future<void> _syncGuestBookmarks() async {
    final guest = AppState.instance.deviceSavedStories;
    if (guest.isEmpty || !AppState.instance.isLoggedIn) return;
    debugPrint('[Bookmark] copying ${guest.length} guest bookmark(s) '
        'to the account');

    final Set<String> onServer;
    try {
      onServer = (await ApiService.instance.getBookmarks())
          .map((i) => i.contentId)
          .toSet();
    } catch (e) {
      debugPrint('[Bookmark] guest copy postponed, list failed: '
          '${_message(e)}');
      return;
    }

    for (final story in guest) {
      final id = _idOf(story);
      if (id.isEmpty) continue;
      try {
        if (!onServer.contains(id)) {
          if (story.isUgc) {
            final r =
                await _dio.post(EngagementEndpoints.ugcBookmarkToggle(id));
            if (_data(r)['bookmarked'] != true) {
              throw Exception('toggle did not add it');
            }
          } else {
            await ApiService.instance.addBookmark(id);
          }
        }
        await AppState.instance.removeDeviceSavedStory(id);
        AppState.instance.setBookmarked(id, true);
        debugPrint('[Bookmark] guest bookmark $id copied to the account');
      } catch (e) {
        final code = e is DioException ? e.response?.statusCode : null;
        if (code == 400 || code == 404) {
          // Handover §9: the story is unpublished or gone; it can never be
          // saved, so stop retrying it.
          await AppState.instance.removeDeviceSavedStory(id);
          AppState.instance.setBookmarked(id, false);
          debugPrint('[Bookmark] guest bookmark $id no longer available '
              '($code); dropped');
        } else {
          debugPrint('[Bookmark] guest bookmark $id kept on the phone: '
              '${_message(e)}');
        }
      }
    }
  }

  // --- Report -------------------------------------------------------------

  Future<ReportOutcome> report(NewsArticle story,
      {required String reason, String? notes}) async {
    final id = _idOf(story);
    if (id.isEmpty) return ReportOutcome.failed;

    if (!story.isUgc && _unsupported.contains(_kArticleReport)) {
      return ReportOutcome.unsupported;
    }
    try {
      if (story.isUgc) {
        // Backend accepts any reason string up to 100 chars (§12), so the
        // same five reasons as desk articles are sent as-is.
        await _dio.post(EngagementEndpoints.ugcReport, data: {
          'submission_id': id,
          'reason': reason,
          if ((notes ?? '').isNotEmpty) 'notes': notes,
        });
      } else {
        await _dio.post(EngagementEndpoints.articleReport(id), data: {
          'reason': reason,
          if ((notes ?? '').isNotEmpty) 'notes': notes,
        });
      }
      return ReportOutcome.sent;
    } catch (e) {
      final message = _message(e).toLowerCase();
      if (message.contains('already reported')) {
        return ReportOutcome.alreadyReported;
      }
      if (!story.isUgc && _isUnsupported(e)) {
        _unsupported.add(_kArticleReport);
        return ReportOutcome.unsupported;
      }
      debugPrint('[Engagement] report failed: $e');
      return ReportOutcome.failed;
    }
  }

  static String _message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['errors'] is Map) {
        return (data['errors']['message'] ?? '').toString();
      }
      return (e.error ?? e.message ?? '').toString();
    }
    return e.toString();
  }
}
