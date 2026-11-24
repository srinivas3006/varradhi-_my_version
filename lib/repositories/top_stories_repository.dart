import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spotlight_item.dart';
import '../models/unified_feed_item.dart';
import '../services/dio_client.dart';
import '../state/app_state.dart';

class TopStoriesQuery {
  TopStoriesQuery.fromApp(AppState app)
      : this(
          lang: app.feedLang,
          viewer: app.isLoggedIn ? app.userId ?? '' : '',
          state: app.feedPlace.state,
          district: app.feedPlace.district,
          city: app.feedCity,
          subdistrict: app.feedPlace.subdistrict,
          village: app.feedPlace.village,
        );

  TopStoriesQuery({
    required String lang,
    String viewer = '',
    int limit = 10,
    String state = '',
    String district = '',
    String city = '',
    String subdistrict = '',
    String village = '',
  })  : parameters = Map.unmodifiable({
          'lang': lang.trim().isEmpty ? 'all' : lang.trim().toLowerCase(),
          'limit': limit.clamp(1, 20).toString(),
          for (final entry in {
            'state': state,
            'district': district,
            'city': city,
            'subdistrict': subdistrict,
            'village': village,
          }.entries)
            if (_savedPlace(entry.value).isNotEmpty)
              entry.key: _savedPlace(entry.value),
        }),
        _viewer = viewer;

  final Map<String, String> parameters;
  final String _viewer;

  String get cacheKey => 'spotlight_top_stories_v1?${Uri(queryParameters: {
            ...parameters
                .map((key, value) => MapEntry(key, value.toLowerCase())),
            'viewer': _viewer,
          }).query}';

  static String _savedPlace(String value) {
    final place = AppState.cleanPlace(value);
    const placeholders = {
      'any',
      'none',
      'n/a',
      'na',
      '-',
      'select location',
      'select state',
      'select district',
      'select city',
      'select subdistrict',
      'select village',
      'select mandal'
    };
    return placeholders.contains(place.toLowerCase()) ? '' : place;
  }
}

class TopStoriesFailure implements Exception {
  const TopStoriesFailure(
      {this.status,
      this.details = const [],
      this.retryAt,
      this.offline = false});

  final int? status;
  final List<String> details;
  final DateTime? retryAt;
  final bool offline;
}

class TopStoriesRepository {
  TopStoriesRepository({Dio? dio, DateTime Function()? now})
      : _dio = dio,
        _now = now ?? DateTime.now;

  static final instance = TopStoriesRepository();
  static const endpoint = '/api/v1/feed/top-stories/';
  final Dio? _dio;
  final DateTime Function() _now;
  final Map<String, TopStoriesFailure> _invalidQueries = {};
  DateTime? _rateLimitedUntil;

  Future<List<SpotlightItem>> cached(TopStoriesQuery query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(query.cacheKey);
      final data = raw == null ? null : jsonDecode(raw);
      return data is List ? parse(data) : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<SpotlightItem>> fetch(
      TopStoriesQuery query, CancelToken token) async {
    final invalid = _invalidQueries[query.cacheKey];
    if (invalid != null) throw invalid;
    final limitedUntil = _rateLimitedUntil;
    if (limitedUntil != null && limitedUntil.isAfter(_now())) {
      throw TopStoriesFailure(status: 429, retryAt: limitedUntil);
    }
    try {
      final response = await (_dio ?? DioClient().dio).get(
        endpoint,
        queryParameters: query.parameters,
        cancelToken: token,
        options: Options(validateStatus: (status) => status == 200),
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! List) throw const TopStoriesFailure();
      final stories = parse(data);
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!token.isCancelled) {
          await prefs.setString(query.cacheKey, jsonEncode(data));
        }
      } catch (_) {
        // The feed is still available when preferences cannot be written.
      }
      return stories;
    } on DioException catch (error) {
      final response = error.response;
      final status = response?.statusCode;
      final body = response?.data;
      final errors = body is Map ? body['errors'] : null;
      final details = errors is Map ? errors['details'] : null;
      final failure = TopStoriesFailure(
        status: status,
        details: status == 400 ? _fieldMessages(details) : const [],
        retryAt: status == 429
            ? _retryAt(response?.headers.value('retry-after')) ??
                _now().add(const Duration(seconds: 60))
            : null,
        offline: error.type == DioExceptionType.connectionError ||
            error.error is SocketException,
      );
      if (!token.isCancelled) {
        if (status == 400) _invalidQueries[query.cacheKey] = failure;
        if (status == 429) _rateLimitedUntil = failure.retryAt;
      }
      throw failure;
    }
  }

  DateTime? _retryAt(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    if (seconds != null && seconds >= 0) {
      return _now().add(Duration(seconds: seconds));
    }
    try {
      return HttpDate.parse(header);
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }

  static List<String> _fieldMessages(dynamic details, [String field = '']) {
    if (details is Map) {
      return [
        for (final entry in details.entries)
          ..._fieldMessages(entry.value,
              field.isEmpty ? '${entry.key}' : '$field.${entry.key}'),
      ];
    }
    if (details is List) {
      return [for (final detail in details) ..._fieldMessages(detail, field)];
    }
    if (details is String && details.trim().isNotEmpty) {
      return [field.isEmpty ? details : '$field: $details'];
    }
    return const [];
  }

  static List<SpotlightItem> parse(List<dynamic> data) {
    final stories = <SpotlightItem>[];
    for (final raw in data.whereType<Map<String, dynamic>>()) {
      final type = raw['type']?.toString().trim().toLowerCase();
      if (type != 'article' && type != 'ugc') continue;
      final metadata = raw['metadata'] is Map
          ? Map<String, dynamic>.from(raw['metadata'] as Map)
          : <String, dynamic>{};
      final slug = metadata['slug']?.toString().trim() ?? '';
      final rawId = type == 'ugc'
          ? metadata['submission_id'] ??
              raw['submission_id'] ??
              metadata['source_id'] ??
              raw['id']
          : raw['id'];
      final id = rawId?.toString().trim() ?? '';
      if (id.isEmpty || (type == 'article' && slug.isEmpty)) continue;
      final story = UnifiedFeedItem.fromJson({
        ...raw,
        'id': id,
        if (type == 'article') 'slug': slug,
        'metadata': {
          ...metadata,
          if (raw['view_count'] != null) 'view_count': raw['view_count'],
        },
      }).toArticle();
      stories.add(SpotlightItem.standard(
        story,
        isEditorialHighlight: metadata['is_top_story'] == true &&
            metadata['top_story_reason'] == 'editorial',
      ));
    }
    return List.unmodifiable(stories);
  }
}
