import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';

/// Represents a trackable backend ad event.
class AdEvent {
  final String adId;
  final String eventType;
  final String placementZone;
  final DateTime timestamp;
  int retryCount;

  AdEvent({
    required this.adId,
    required this.eventType,
    this.placementZone = 'feed',
    DateTime? timestamp,
    this.retryCount = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'ad_id': adId,
        'event_type': eventType,
        'placement_zone': placementZone,
      };

  @override
  String toString() =>
      'AdEvent($eventType for adId=$adId in zone=$placementZone, retries=$retryCount)';
}

/// Asynchronous, non-blocking event queue for dispatching ad events.
/// Handles transient network failures with exponential retry backoff.
class AdEventQueue {
  static final AdEventQueue instance = AdEventQueue._internal();
  AdEventQueue._internal();

  /// Maximum number of delivery retries per event before dropping.
  static const int maxRetries = 3;

  /// Maximum number of events allowed in the offline retry queue.
  static const int maxQueueSize = 50;

  /// Internal FIFO queue of pending events.
  final List<AdEvent> _queue = [];

  bool _isProcessing = false;
  Timer? _retryTimer;

  /// Number of pending events in queue (exposed for testability).
  int get pendingCount => _queue.length;

  /// Visible for testing: clear all pending queue events and cancel retry timer.
  void reset() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _queue.clear();
    _isProcessing = false;
  }

  /// Enqueues an ad event for non-blocking asynchronous delivery.
  void enqueue({
    required String adId,
    required String eventType,
    String placementZone = 'feed',
  }) {
    final trimmedAdId = adId.trim();
    if (trimmedAdId.isEmpty) return;

    final trimmedType = eventType.trim().toLowerCase();
    final trimmedZone = placementZone.trim();

    // Bounded queue: evict oldest if capacity is reached under offline conditions
    if (_queue.length >= maxQueueSize) {
      _queue.removeAt(0);
    }

    final event = AdEvent(
      adId: trimmedAdId,
      eventType: trimmedType,
      placementZone: trimmedZone,
    );

    _queue.add(event);
    _scheduleProcessing();
  }

  /// Immediately processes or schedules processing of the queue.
  void _scheduleProcessing([Duration delay = Duration.zero]) {
    if (_isProcessing) return;

    if (delay == Duration.zero) {
      _processQueue();
    } else {
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, _processQueue);
    }
  }

  /// Processes queued events one by one in the background.
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        final currentEvent = _queue.first;

        try {
          await ApiClient.instance.dio.post(
            '/api/v1/ads/event/',
            data: currentEvent.toJson(),
          );

          // Success - remove from queue
          _queue.removeAt(0);
          debugPrint('[AdEventQueue] Sent: $currentEvent');
        } catch (e) {
          debugPrint('[AdEventQueue] Error sending $currentEvent: $e');

          currentEvent.retryCount++;
          if (currentEvent.retryCount >= maxRetries) {
            // Exceeded max retries, drop to prevent queue blockage
            debugPrint(
                '[AdEventQueue] Dropping event after $maxRetries failures: $currentEvent');
            _queue.removeAt(0);
          } else {
            // Transient failure: backoff and retry later
            _isProcessing = false;
            final backoff =
                Duration(milliseconds: 1000 * (1 << currentEvent.retryCount));
            _scheduleProcessing(backoff);
            return;
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Awaits processing of all currently queued items (useful for testing).
  Future<void> flush() async {
    while (_queue.isNotEmpty && (_isProcessing || _retryTimer != null)) {
      _retryTimer?.cancel();
      _retryTimer = null;
      await _processQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}
