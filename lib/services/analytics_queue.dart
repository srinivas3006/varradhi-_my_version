import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_article.dart';
import '../state/app_state.dart';
import 'api_service.dart';
import 'dio_client.dart';

/// Content analytics for desk articles and citizen (UGC) news — Vaaradhi APK
/// analytics handover.
///
/// Events are written to a small queue on the phone and sent in bulk to
/// `POST /api/v1/analytics/events/bulk/` (at most 100 per request) without
/// ever blocking the screen:
///  * removed only after 202 Accepted — never resent after it;
///  * 400: that batch is dropped (resending it can never succeed, and kept
///    it blocked every later event);
///  * 429: kept, next try after a minute;
///  * network, 401, 5xx: kept, retried after 5 s, 15 s, 60 s, then when the
///    app returns to the foreground;
///  * 403: kept until the app is next opened;
///  * one flush at a time.
class AnalyticsQueue with WidgetsBindingObserver {
  AnalyticsQueue._({Dio? dio}) : _dioOverride = dio;
  static final AnalyticsQueue instance = AnalyticsQueue._();

  @visibleForTesting
  factory AnalyticsQueue.forTesting(Dio dio) => AnalyticsQueue._(dio: dio);

  static const defaultEndpoint = '/api/v1/analytics/events/bulk/';
  static const _prefsKey = 'analytics_event_queue_v1';
  static const _maxQueued = 500;
  static const maxBatch = 100;
  static const _flushAt = 20;

  /// Sent shortly after an event so it reaches the dashboard soon, while
  /// still batching a burst of them.
  static const _flushDelay = Duration(seconds: 10);

  static const retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
  ];

  /// The content events the backend accepts. Anything else is not queued:
  /// one unknown event made the backend reject (400) its whole batch.
  static const contentEvents = {
    'article_impression',
    'article_open',
    'scroll_depth',
    'read_completion',
    'bookmark',
    'share',
    'reaction',
    'video_start',
    'video_progress',
    'video_complete',
  };

  static const maxDwellSeconds = 86400;

  final Dio? _dioOverride;
  Dio get _dio => _dioOverride ?? DioClient().dio;

  final List<Map<String, dynamic>> _queue = [];
  bool _loaded = false;
  bool _started = false;
  bool _flushing = false;
  int _failures = 0;
  Timer? _timer;

  /// The home bootstrap may advertise where to send events
  /// (`offline_support.analytics_bulk_endpoint`).
  String endpoint = defaultEndpoint;

  @visibleForTesting
  List<Map<String, dynamic>> get pending => List.unmodifiable(_queue);

  /// Idempotent. Flushes when the app goes to the background and when it
  /// comes back.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ensureLoaded().then((_) => flush()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Back in the foreground: the "later retries" point.
      _failures = 0;
      unawaited(flush());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(flush());
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is List) {
        _queue.insertAll(
            0,
            list
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                // Events an older app version queued that the backend
                // rejects would block the queue again.
                .where(_isValid));
      }
    } catch (_) {
      // A corrupt queue is not worth crashing for; start fresh.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_queue));
    } catch (_) {}
  }

  static String get _sessionId {
    final session = AppState.instance.sessionId;
    if (session != null && session.isNotEmpty) return session;
    return AppState.instance.deviceId;
  }

  static final _uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// The content id field for [story]: `submission_id` for citizen news,
  /// `article_id` for desk articles — never both, never a slug. Null when
  /// the story has no UUID (nothing is sent for it).
  static MapEntry<String, String>? contentIdOf(NewsArticle story) {
    final id = story.id.trim();
    if (!_uuid.hasMatch(id)) return null;
    if (story.contentKind == 'live') return null;
    return MapEntry(story.isUgc ? 'submission_id' : 'article_id', id);
  }

  static bool _isValid(Map<String, dynamic> e) {
    if (!contentEvents.contains(e['event_type'])) return false;
    final hasArticle = e['article_id'] != null;
    final hasSubmission = e['submission_id'] != null;
    return hasArticle != hasSubmission;
  }

  /// Queues one content event for [story]. Never throws, never blocks.
  /// [dwellSeconds] and [scrollDepth] are sent only when given.
  Future<void> trackContent(
    String eventType,
    NewsArticle story, {
    int? dwellSeconds,
    int? scrollDepth,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!contentEvents.contains(eventType)) return;
    final id = contentIdOf(story);
    if (id == null) return;
    // Queued at once (before any await) once the stored queue is loaded.
    if (!_loaded) await _ensureLoaded();
    final guestId = AppState.instance.deviceId;
    _queue.add({
      'event_type': eventType,
      id.key: id.value,
      if (guestId.isNotEmpty) 'guest_id': guestId,
      'session_id': _sessionId,
      'language': AppState.instance.contentLanguage ?? 'te',
      'device_type': ApiService.deviceType,
      if (dwellSeconds != null)
        'dwell_seconds': dwellSeconds.clamp(0, maxDwellSeconds),
      if (scrollDepth != null) 'scroll_depth': scrollDepth.clamp(0, 100),
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'metadata': metadata,
    });
    if (_queue.length > _maxQueued) {
      _queue.removeRange(0, _queue.length - _maxQueued); // drop oldest
    }
    await _save();
    if (_queue.length >= _flushAt) {
      unawaited(flush());
    } else {
      _schedule(_flushDelay);
    }
  }

  static const singleEndpoint = '/api/v1/analytics/events/';

  /// `notification_opened`, sent once the tapped notification's screen has
  /// opened — never when a push merely arrives (notification handover).
  /// Its own request to the single-event endpoint, retried after 5 s, 15 s
  /// and 60 s on network trouble or 5xx; never on 4xx.
  Future<void> notificationOpened(String notificationId,
      {int attempt = 0}) async {
    final id = notificationId.trim();
    if (!_uuid.hasMatch(id)) return; // device-only ids (push_…) are not sent
    final guestId = AppState.instance.deviceId;
    int? status;
    try {
      final r = await _dio.post(
        singleEndpoint,
        data: {
          'event_type': 'notification_opened',
          'notification_id': id,
          if (guestId.isNotEmpty) 'guest_id': guestId,
          'session_id': _sessionId,
          'device_type': ApiService.deviceType,
        },
        options: Options(validateStatus: (_) => true),
      );
      status = r.statusCode;
    } catch (_) {
      status = null;
    }
    final retry = status == null || status >= 500 || status == 429;
    if (retry && attempt < retryDelays.length && timersEnabled) {
      Timer(retryDelays[attempt],
          () => unawaited(notificationOpened(id, attempt: attempt + 1)));
    }
  }

  /// Older call sites (feed refresh, category chips): not content events,
  /// so the backend has nothing to record them as — kept as a no-op.
  Future<void> track(String eventType,
      {Map<String, dynamic> metadata = const {}}) async {}

  /// Off in widget tests: a pending timer at the end of a test fails it.
  @visibleForTesting
  bool timersEnabled = !Platform.environment.containsKey('FLUTTER_TEST');

  void _schedule(Duration delay) {
    if (!timersEnabled) return;
    if (_timer?.isActive ?? false) return;
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Sends queued events in batches of up to [maxBatch].
  /// One flush at a time: a call during a flush waits for that one.
  Future<void> flush() => _inFlight ??= _flush().whenComplete(() {
        _inFlight = null;
      });

  Future<void>? _inFlight;

  Future<void> _flush() async {
    await _ensureLoaded();
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    _timer?.cancel();
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.take(maxBatch).toList();
        int? status;
        try {
          final response = await _dio.post(
            endpoint,
            data: {'events': batch},
            options: Options(validateStatus: (_) => true),
          );
          status = response.statusCode;
        } catch (e) {
          status = null; // offline / timeout
        }

        if (status == 202 || status == 200 || status == 201) {
          // Accepted: these are never sent again.
          _queue.removeRange(0, batch.length);
          _failures = 0;
          await _save();
          continue;
        }
        if (status == 400 || status == 413 || status == 422) {
          // This batch can never succeed; drop it so the rest can go.
          debugPrint('[Analytics] batch rejected ($status), dropped');
          _queue.removeRange(0, batch.length);
          await _save();
          continue;
        }
        if (status == 403) {
          // Not until authorization changes (next app start).
          break;
        }
        if (status == 429) {
          _schedule(retryDelays.last);
          break;
        }
        // Network, 401 (the client refreshes the token), 5xx: back off.
        if (_failures < retryDelays.length) {
          _schedule(retryDelays[_failures]);
        }
        _failures++;
        break;
      }
    } finally {
      _flushing = false;
    }
  }

  @visibleForTesting
  void resetForTest() {
    _queue.clear();
    _loaded = true;
    _flushing = false;
    _failures = 0;
    _timer?.cancel();
    endpoint = defaultEndpoint;
    _inFlight = null;
  }
}
