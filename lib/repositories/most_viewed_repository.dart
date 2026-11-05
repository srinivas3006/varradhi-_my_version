import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_article.dart';
import '../models/unified_feed_item.dart';
import '../services/dio_client.dart';

/// One story of the Most Viewed row. The list order is the backend's ranking
/// and is never changed here.
class MostViewedItem {
  const MostViewedItem(this.story, this.periodViews);

  final NewsArticle story;

  /// `period_view_count`: unique readers in the period. This is the number
  /// to show; `view_count` is a different counter (0 for citizen news).
  final int periodViews;

  /// Null for what the row cannot open: an unknown type, or an article with
  /// no slug (article detail is by slug only).
  static MostViewedItem? parse(Map<String, dynamic> json) {
    final type = json['type']?.toString().trim().toLowerCase();
    if (type != 'article' && type != 'ugc') return null;
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};
    final slug = (json['slug'] ?? metadata['slug'])?.toString().trim() ?? '';
    if (type == 'article' && slug.isEmpty) return null;
    final id = (json['id'] ?? metadata['source_id'])?.toString().trim() ?? '';
    if (id.isEmpty) return null;

    final story = UnifiedFeedItem.fromJson({
      ...json,
      'id': id,
      'metadata': {
        ...metadata,
        if (json['view_count'] != null) 'view_count': json['view_count'],
      },
    }).toArticle();
    final views = json['period_view_count'];
    return MostViewedItem(
      story,
      views is num ? views.toInt() : int.tryParse('$views') ?? 0,
    );
  }

  static List<MostViewedItem> parseList(List<dynamic> data) => [
        for (final raw in data)
          if (raw is Map)
            if (parse(Map<String, dynamic>.from(raw)) case final item?) item,
      ];
}

/// What a request means for the row.
class MostViewedAnswer {
  const MostViewedAnswer.items(List<MostViewedItem> this.items)
      : throttled = false;
  const MostViewedAnswer.keep({this.throttled = false}) : items = null;

  /// The row to show (empty hides it). Null: keep what is on screen.
  final List<MostViewedItem>? items;

  /// 429: try again later.
  final bool throttled;
}

/// `GET /api/v1/feed/most-viewed/`: optional Home content, so nothing here
/// throws and no failure can affect the Home feed.
class MostViewedRepository {
  MostViewedRepository._({Dio? dio}) : _dioOverride = dio;
  static final MostViewedRepository instance = MostViewedRepository._();

  @visibleForTesting
  factory MostViewedRepository.forTesting(Dio dio) =>
      MostViewedRepository._(dio: dio);

  static const endpoint = '/api/v1/feed/most-viewed/';
  static const period = '24h';
  static const limit = 10;
  static const _prefsPrefix = 'home_most_viewed_v1:';

  final Dio? _dioOverride;
  Dio get _dio => _dioOverride ?? DioClient().dio;

  static Map<String, String> _params({
    required String lang,
    required String state,
    required String district,
    required String city,
    required String subdistrict,
    required String village,
  }) =>
      {
        'lang': lang.isNotEmpty ? lang : 'all',
        'period': period,
        'limit': '$limit',
        if (state.isNotEmpty) 'state': state,
        if (district.isNotEmpty) 'district': district,
        if (city.isNotEmpty) 'city': city,
        if (subdistrict.isNotEmpty) 'subdistrict': subdistrict,
        if (village.isNotEmpty) 'village': village,
      };

  /// Per reader as well: each item carries that account's bookmark and
  /// reaction.
  static String _cacheKey(String viewer, Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    return '$_prefsPrefix'
            'viewer=$viewer&${keys.map((k) => '$k=${params[k]}').join('&')}'
        .toLowerCase();
  }

  /// The last row kept for this reader, language and place.
  Future<List<MostViewedItem>> cached({
    required String viewer,
    required String lang,
    required String state,
    required String district,
    required String city,
    required String subdistrict,
    required String village,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(
          viewer,
          _params(
              lang: lang,
              state: state,
              district: district,
              city: city,
              subdistrict: subdistrict,
              village: village)));
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      return list is List ? MostViewedItem.parseList(list) : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<MostViewedAnswer> fetch({
    required String viewer,
    required String lang,
    required String state,
    required String district,
    required String city,
    required String subdistrict,
    required String village,
  }) async {
    final params = _params(
        lang: lang,
        state: state,
        district: district,
        city: city,
        subdistrict: subdistrict,
        village: village);
    final key = _cacheKey(viewer, params);
    try {
      final response = await _dio.get(endpoint, queryParameters: params);
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! List) return const MostViewedAnswer.keep();
      final items = MostViewedItem.parseList(data);
      await _store(key, items.isEmpty ? null : data);
      return MostViewedAnswer.items(items);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400) {
        debugPrint('[MostViewed] rejected: ${e.response?.data}');
        await _store(key, null);
        return const MostViewedAnswer.items([]);
      }
      debugPrint('[MostViewed] failed (${status ?? e.type}); keeping the row');
      return MostViewedAnswer.keep(throttled: status == 429);
    } catch (e) {
      debugPrint('[MostViewed] failed: $e');
      return const MostViewedAnswer.keep();
    }
  }

  Future<void> _store(String key, List<dynamic>? data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (data == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(data));
      }
    } catch (_) {}
  }
}
