import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/ad_banner.dart';
import '../../state/app_state.dart';
import '../network/api_response.dart';
import '../network/dio_client.dart';
import 'ad_placement.dart';

class AdEvent {
  final String adId;
  final String eventType;
  final String placementZone;
  final DateTime timestamp;
  final AdExposure? exposure;
  final String deviceId;
  final Map<String, num> telemetry;
  int retryCount;

  AdEvent({
    required this.adId,
    required this.eventType,
    this.placementZone = 'feed',
    DateTime? timestamp,
    this.exposure,
    this.deviceId = '',
    this.telemetry = const {},
    this.retryCount = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        if (exposure != null) ...telemetry,
        'ad_id': adId,
        'event_type': eventType,
        'placement_zone': placementZone,
        if (exposure != null) ...{
          'tracking_version': 2,
          'exposure_id': exposure!.id,
        },
      };

  @override
  String toString() =>
      'AdEvent($eventType for adId=$adId in zone=$placementZone, retries=$retryCount)';
}

/// FIFO delivery keeps exposure events behind their rendered impression.
class AdEventQueue {
  static final AdEventQueue instance = AdEventQueue();
  AdEventQueue({Dio? dio}) : _dio = dio;

  static const int maxRetries = 3;
  static const int maxQueueSize = 50;
  final Dio? _dio;
  final invalidation = ValueNotifier<int>(0);
  final _queue = <(AdEvent, Completer<Map?>)>[];
  final _accepted = <(String, String), (DateTime, Map)>{};
  final _invalid = <String, DateTime>{};
  bool _isProcessing = false;
  int _generation = 0;
  Timer? _retryTimer;

  int get pendingCount => _queue.length;
  bool isInvalid(AdExposure? exposure) =>
      exposure != null && _invalid.containsKey(exposure.id);

  void reset() {
    ++_generation;
    _retryTimer?.cancel();
    _retryTimer = null;
    for (final entry in _queue) {
      entry.$2.complete(null);
    }
    _queue.clear();
    _accepted.clear();
    _invalid.clear();
    _isProcessing = false;
  }

  Future<Map?> enqueue({
    required String adId,
    required String eventType,
    String placementZone = 'feed',
    AdExposure? exposure,
    Map<String, num> telemetry = const {},
  }) async {
    final now = DateTime.now();
    _accepted.removeWhere((_, value) => !value.$1.isAfter(now));
    _invalid.removeWhere((_, until) => !until.isAfter(now));
    if (adId.trim().isEmpty ||
        isInvalid(exposure) ||
        (exposure != null &&
            (!exposure.isValidAt(now) || exposure.deviceId.isEmpty))) {
      return null;
    }
    final type = eventType.trim().toLowerCase();
    if (exposure != null) {
      final accepted = _accepted[(exposure.id, type)];
      if (accepted != null) return accepted.$2;
      for (final (event, result) in _queue) {
        if (event.exposure?.id == exposure.id && event.eventType == type) {
          return result.future;
        }
      }
    }
    if (_queue.length >= maxQueueSize) return null;

    final result = Completer<Map?>();
    _queue.add((
      AdEvent(
        adId: adId.trim(),
        eventType: type,
        placementZone: AdPlacement.canonical(placementZone),
        exposure: exposure,
        deviceId: exposure?.deviceId ?? AppState.instance.deviceId,
        telemetry: Map.unmodifiable(telemetry),
      ),
      result,
    ));
    unawaited(_processQueue());
    return result.future;
  }

  static const _requiresImpression = {
    'click',
    'video_start',
    'video_25',
    'video_50',
    'video_75',
    'video_complete',
    'video_watch',
  };

  Future<void> _processQueue() async {
    if (_isProcessing || _retryTimer != null || _queue.isEmpty) return;
    _isProcessing = true;
    final generation = _generation;
    try {
      while (_queue.isNotEmpty && generation == _generation) {
        final (event, result) = _queue.first;
        final exposure = event.exposure;
        if (exposure != null &&
            (!exposure.isValidAt(DateTime.now()) ||
                isInvalid(exposure) ||
                (_requiresImpression.contains(event.eventType) &&
                    !_accepted.containsKey((exposure.id, 'impression'))))) {
          _queue.removeAt(0);
          result.complete(null);
          continue;
        }

        final clickThrough = exposure != null && event.eventType == 'click';
        try {
          final response = await (_dio ?? ApiClient.instance.dio).post(
            clickThrough ? '/api/v1/ads/click-through/' : '/api/v1/ads/event/',
            data: clickThrough ? {'exposure_id': exposure.id} : event.toJson(),
            options: Options(headers: {
              if (event.deviceId.isNotEmpty) 'X-Device-ID': event.deviceId,
            }),
          );
          if (generation != _generation) return;
          final raw = response.data;
          final data = raw is Map && raw['errors'] == null ? raw['data'] : null;
          final accepted = exposure == null
              ? <String, dynamic>{}
              : data is Map && data['recorded'] is bool
                  ? data
                  : null;
          if (exposure != null && accepted != null) {
            _accepted[(exposure.id, event.eventType)] =
                (exposure.expiresAt!, accepted);
          }
          _queue.removeAt(0);
          result.complete(accepted);
        } on DioException catch (error) {
          if (generation != _generation) return;
          final status = error.response?.statusCode;
          final raw = error.response?.data;
          final details =
              ApiError.fromJson(raw is Map ? raw['errors'] : null).details;
          if (exposure != null &&
              (status == 404 ||
                  (status == 400 &&
                      details is Map &&
                      details.keys.any({
                        'exposure_id',
                        'ad_id',
                        'placement_zone'
                      }.contains)))) {
            _invalid[exposure.id] = exposure.expiresAt!;
            invalidation.value++;
          }
          event.retryCount++;
          final transient =
              (status == null && error.type != DioExceptionType.cancel) ||
                  status == 429 ||
                  (status != null && status >= 500);
          if (transient && event.retryCount < maxRetries) {
            final delay =
                _retryAfter(error) ?? Duration(seconds: 1 << event.retryCount);
            if (exposure?.expiresAt?.isAfter(DateTime.now().add(delay)) ??
                true) {
              _retryTimer = Timer(delay, () {
                _retryTimer = null;
                unawaited(_processQueue());
              });
              return;
            }
          }
          _queue.removeAt(0);
          result.complete(null);
          debugPrint('[Ads] Event ${event.eventType} failed ($status); '
              'validation fields: ${details is Map ? details.keys : []}');
        } catch (_) {
          if (generation != _generation) return;
          _queue.removeAt(0);
          result.complete(null);
        }
      }
    } finally {
      if (generation == _generation) _isProcessing = false;
    }
  }

  static Duration? _retryAfter(DioException error) {
    if (error.response?.statusCode != 429) return null;
    final raw = error.response?.headers.value('retry-after')?.trim();
    if (raw == null) return null;
    final seconds = int.tryParse(raw);
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    try {
      final delay = HttpDate.parse(raw).difference(DateTime.now());
      return delay.isNegative ? Duration.zero : delay;
    } catch (_) {
      return null;
    }
  }

  Future<void> flush() async {
    while (_queue.isNotEmpty) {
      await _processQueue();
      if (_queue.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  }
}
