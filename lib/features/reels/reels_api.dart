import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../state/app_state.dart';
import 'reel_model.dart';

class ReelsPage {
  const ReelsPage(this.items, this.next);
  final List<Reel> items;

  /// `meta.next` exactly as sent; null on the last page.
  final String? next;
}

class ReelsApiException implements Exception {
  ReelsApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  bool get isInvalidCursor => statusCode == 400;
  @override
  String toString() => 'ReelsApiException($statusCode): $message';
}

/// `GET /api/v1/articles/shorts-feed/` — a public endpoint; the login token
/// is optional.
///
/// Uses its own client, not the app's shared one: that one logs the reader
/// out when a 401 cannot be refreshed, whereas the Reels contract is to drop
/// a bad token and retry anonymously. 429 backs off 2s, 4s, 8s.
class ReelsApi {
  ReelsApi({Dio? dio, this.authToken, this.deviceId})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              // Status codes are handled below, not thrown.
              validateStatus: (_) => true,
            ));

  /// Reads the signed-in reader's token and device id from the app.
  factory ReelsApi.forApp() => ReelsApi(
        authToken: AppState.instance.isLoggedIn
            ? AppState.instance.authToken
            : null,
        deviceId: AppState.instance.deviceId,
      );

  static const path = '/api/v1/articles/shorts-feed/';

  final Dio _dio;

  /// Dropped for the rest of the session after a 401.
  String? authToken;
  final String? deviceId;

  /// Waits between 429 retries; replaceable in tests.
  @visibleForTesting
  Future<void> Function(Duration) wait = Future<void>.delayed;

  Future<ReelsPage> fetch({
    String? nextUrl,
    String scope = 'main',
    Map<String, String> location = const {},
    int pageSize = 20,
  }) {
    if (nextUrl != null) {
      // Always meta.next as sent — never a built page=2.
      return _get(nextUrl, null);
    }
    return _get(path, {
      'scope': scope,
      'page_size': pageSize.clamp(1, 50),
      for (final e in location.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    });
  }

  Future<ReelsPage> _get(String url, Map<String, dynamic>? query,
      {int attempt = 0}) async {
    final token = authToken;
    final headers = <String, dynamic>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (deviceId != null && deviceId!.isNotEmpty) 'X-Device-ID': deviceId,
    };

    final Response<dynamic> res;
    try {
      res = await _dio.get(url,
          queryParameters: query, options: Options(headers: headers));
    } on DioException catch (e) {
      throw ReelsApiException(
          0, e.message ?? 'Network error. Please check your connection.');
    }
    final status = res.statusCode ?? 0;

    if (status == 401 && token != null && token.isNotEmpty) {
      // Public endpoint: an expired or malformed token must not block it.
      authToken = null;
      return _get(url, query, attempt: attempt);
    }
    if (status == 429 && attempt < 3) {
      await wait(Duration(seconds: 1 << (attempt + 1))); // 2s, 4s, 8s
      return _get(url, query, attempt: attempt + 1);
    }

    final body = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
    if (status != 200) {
      final errors = body['errors'];
      final msg = (errors is Map ? errors['message'] : null) ??
          'Request failed ($status)';
      throw ReelsApiException(status, msg.toString());
    }

    final data = body['data'];
    final items = (data is List ? data : const [])
        .whereType<Map>()
        .map((m) => Reel.fromJson(Map<String, dynamic>.from(m)))
        .where((r) => r.id.isNotEmpty)
        .toList();
    final meta = body['meta'];
    final next = meta is Map ? meta['next']?.toString() : null;
    return ReelsPage(items, (next == null || next.isEmpty) ? null : next);
  }
}
