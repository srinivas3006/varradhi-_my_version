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
  static const _kUgcBookmark = 'ugc_bookmark';
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

  // --- Save / Bookmark ----------------------------------------------------

  /// Toggles the saved state towards [nowSaved] and returns the state that
  /// actually holds afterwards, or null on failure.
  ///
  /// Citizen posts: the server answers `{bookmarked: bool}` and that value
  /// is the truth (the endpoint is a toggle, so it can disagree with the
  /// optimistic guess). `GET /api/v1/bookmarks/` is article-only, so a copy
  /// of each saved citizen post is also kept on the device for the
  /// Bookmarks screen to list.
  Future<bool?> setSaved(NewsArticle story, {required bool nowSaved}) async {
    final id = _idOf(story);
    if (!story.isUgc) {
      try {
        var saved = await ApiService.instance.toggleBookmark(id) ?? nowSaved;
        if (saved != nowSaved) {
          // The server already had the state the reader asked for (the
          // app's copy was stale), so the toggle undid it. Toggle once more
          // so the server ends where the reader tapped.
          saved = await ApiService.instance.toggleBookmark(id) ?? nowSaved;
        }
        return saved;
      } catch (e) {
        debugPrint('[Engagement] article bookmark failed: $e');
        return null;
      }
    }

    bool? saved;
    if (!_unsupported.contains(_kUgcBookmark)) {
      try {
        final r = await _dio.post(EngagementEndpoints.ugcBookmarkToggle(id));
        final value = _data(r)['bookmarked'];
        saved = value is bool ? value : nowSaved;
      } catch (e) {
        if (!_isUnsupported(e)) {
          debugPrint('[Engagement] UGC bookmark failed: $e');
          return null;
        }
        _unsupported.add(_kUgcBookmark);
      }
    }
    saved ??= nowSaved; // older server: device-only
    if (saved) {
      await AppState.instance.saveStoryOnDevice(story);
    } else {
      await AppState.instance.removeDeviceSavedStory(id);
      AppState.instance.setBookmarked(id, false);
    }
    return saved;
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
