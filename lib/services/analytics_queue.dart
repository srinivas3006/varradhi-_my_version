import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import 'api_service.dart';
import 'dio_client.dart';

/// Offline-first analytics: events are queued on the device and sent in one
/// request to `POST /api/v1/analytics/events/bulk/` (202 → accepted_count).
///
/// Survives restarts and dead networks: the queue lives in
/// SharedPreferences and is only cleared after the server accepts a batch.
/// Flushes when the batch is full, when the app goes to the background, and
/// after the home bootstrap succeeds (a good sign the network is back).
class AnalyticsQueue with WidgetsBindingObserver {
  AnalyticsQueue._({Dio? dio}) : _dioOverride = dio;
  static final AnalyticsQueue instance = AnalyticsQueue._();

  @visibleForTesting
  factory AnalyticsQueue.forTesting(Dio dio) => AnalyticsQueue._(dio: dio);

  static const defaultEndpoint = '/api/v1/analytics/events/bulk/';
  static const _prefsKey = 'analytics_event_queue_v1';
  static const _maxQueued = 300;
  static const _batchSize = 50;
  static const _flushAt = 20;

  final Dio? _dioOverride;
  Dio get _dio => _dioOverride ?? DioClient().dio;

  final List<Map<String, dynamic>> _queue = [];
  bool _loaded = false;
  bool _started = false;
  bool _flushing = false;

  /// The home bootstrap advertises where to send events
  /// (`offline_support.analytics_bulk_endpoint`).
  String endpoint = defaultEndpoint;

  @visibleForTesting
  List<Map<String, dynamic>> get pending => List.unmodifiable(_queue);

  /// Idempotent. Registers the lifecycle hook that flushes on background.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ensureLoaded());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
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
            0, list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
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

  /// Queues one event. Never throws, never blocks the UI.
  Future<void> track(String eventType,
      {Map<String, dynamic> metadata = const {}}) async {
    await _ensureLoaded();
    // Anonymous events need guest_id or session_id (handover §13); the
    // stable installation id is the guest id.
    final guestId = AppState.instance.deviceId;
    _queue.add({
      'event_type': eventType,
      if (guestId.isNotEmpty) 'guest_id': guestId,
      'session_id': _sessionId,
      'language': AppState.instance.contentLanguage ?? 'te',
      'device_type': ApiService.deviceType,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'metadata': metadata,
    });
    if (_queue.length > _maxQueued) {
      _queue.removeRange(0, _queue.length - _maxQueued); // drop oldest
    }
    await _save();
    if (_queue.length >= _flushAt) unawaited(flush());
  }

  /// Sends queued events in batches. Keeps them on any failure.
  Future<void> flush() async {
    await _ensureLoaded();
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.take(_batchSize).toList();
        final response =
            await _dio.post(endpoint, data: {'events': batch});
        final ok = response.statusCode == 202 ||
            response.statusCode == 200 ||
            response.statusCode == 201;
        if (!ok) break;
        _queue.removeRange(0, batch.length);
        await _save();
      }
    } catch (e) {
      debugPrint('[Analytics] flush deferred: $e');
    } finally {
      _flushing = false;
    }
  }
}
