import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/network/api_response.dart';
import '../core/network/dio_client.dart';
import '../models/video_item.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

/// Production VideoRepository managing:
/// - Retrieval of YouTube Shorts feed and horizontal video feed
/// - Pagination cursor tracking and deduplication
/// - Caching of video lists to prevent redundant network hits on tab switch
/// - Safe error handling
class VideoRepository {
  VideoRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient.instance;

  static final VideoRepository instance = VideoRepository();

  // ignore: unused_field
  final ApiClient _api;

  final Map<String, List<VideoItem>> _cache = {};
  final Map<String, Set<String>> _seenIdsPerKey = {};

  /// Fetches Shorts feed (vertical full-screen items).
  Future<ApiResponse<List<VideoItem>>> getShortsFeed({
    String? cursor,
    int pageSize = 20,
    String? lang,
  }) async {
    final effectiveLang = lang ?? AppState.instance.contentLanguage;
    final key = 'shorts:$effectiveLang';

    try {
      final response = await ApiService.instance.getShortsFeed(
        cursor: cursor,
        pageSize: pageSize,
        lang: effectiveLang,
      );

      if (response.hasErrors)
        throw ApiException(response.errorMessage ?? 'Unable to load videos.');
      final raw = response.data ?? [];
      if (cursor == null) _seenIdsPerKey[key] = <String>{};
      final seen = _seenIdsPerKey.putIfAbsent(key, () => <String>{});
      final deduplicated = <VideoItem>[];

      for (final v in raw) {
        if (v.id.isNotEmpty && seen.add(v.id)) {
          deduplicated.add(v);
        }
      }

      if (cursor == null) {
        _cache[key] = List.from(deduplicated);
      } else {
        _cache[key]?.addAll(deduplicated);
      }

      return ApiResponse<List<VideoItem>>(
        data: deduplicated,
        meta: response.meta,
        errors: response.errors,
        apiError: response.apiError,
        nextCursor: response.nextCursor,
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[VideoRepository] getShortsFeed error: $e');
      throw ApiException('షార్ట్స్ లోడ్ చేయడం విఫలమైంది.');
    }
  }

  /// Fetches regular Video feed (standard video articles).
  Future<ApiResponse<List<VideoItem>>> getVideoFeed({
    String? cursor,
    int pageSize = 20,
    String? lang,
    String? scope,
  }) async {
    final effectiveLang = lang ?? AppState.instance.contentLanguage;
    final key = 'videos:$effectiveLang:${scope ?? "all"}:'
        '${AppState.instance.stateName}:${AppState.instance.district}:'
        '${AppState.instance.city}:${AppState.instance.subdistrict}:${AppState.instance.village}';

    try {
      final response = await ApiService.instance.getVideoFeed(
        cursor: cursor,
        pageSize: pageSize,
        lang: effectiveLang,
        scope: scope,
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        city: AppState.instance.city,
        subdistrict: AppState.instance.subdistrict,
        village: AppState.instance.village,
      );

      if (response.hasErrors)
        throw ApiException(response.errorMessage ?? 'Unable to load videos.');
      final raw = response.data ?? [];
      if (cursor == null) _seenIdsPerKey[key] = <String>{};
      final seen = _seenIdsPerKey.putIfAbsent(key, () => <String>{});
      final deduplicated = <VideoItem>[];

      for (final v in raw) {
        if (v.id.isNotEmpty && seen.add(v.id)) {
          deduplicated.add(v);
        }
      }

      return ApiResponse<List<VideoItem>>(
        data: deduplicated,
        meta: response.meta,
        errors: response.errors,
        apiError: response.apiError,
        nextCursor: response.nextCursor,
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[VideoRepository] getVideoFeed error: $e');
      throw ApiException('వీడియోలు లోడ్ చేయడం విఫలమైంది.');
    }
  }

  List<VideoItem>? getCachedShorts([String? lang]) {
    final effectiveLang = lang ?? AppState.instance.contentLanguage;
    final cached = _cache['shorts:$effectiveLang'];
    return cached != null ? List.unmodifiable(cached) : null;
  }

  void clearCache() {
    _cache.clear();
    _seenIdsPerKey.clear();
  }
}
