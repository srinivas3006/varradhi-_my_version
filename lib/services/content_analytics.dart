import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/media/video_playback_controller.dart';
import '../models/news_article.dart';
import 'analytics_queue.dart';

bool get _inWidgetTest => Platform.environment.containsKey('FLUTTER_TEST');

// --- Impressions -------------------------------------------------------------

/// The impressions already sent on one feed screen ("once per content item
/// per feed-screen session"). Each feed screen owns one and provides it with
/// [ImpressionScope]; cards without a scope share one for the app session.
class ImpressionLog {
  final Set<String> _seen = {};

  static final ImpressionLog appSession = ImpressionLog();

  /// True the first time [story] is seen here.
  bool firstTime(NewsArticle story) {
    final id = AnalyticsQueue.contentIdOf(story);
    if (id == null) return false;
    return _seen.add('${id.key}:${id.value}');
  }
}

/// Provides the screen's [ImpressionLog] to the cards below it.
class ImpressionScope extends InheritedWidget {
  const ImpressionScope({super.key, required this.log, required super.child});

  final ImpressionLog log;

  static ImpressionLog of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ImpressionScope>()?.log ??
      ImpressionLog.appSession;

  @override
  bool updateShouldNotify(ImpressionScope old) => old.log != log;
}

/// Sends `article_impression` once [story]'s card has been at least half
/// visible for about a second — never for cards built off screen.
class ImpressionTracker extends StatefulWidget {
  const ImpressionTracker(
      {super.key, required this.story, required this.child});

  final NewsArticle story;
  final Widget child;

  static const visibleFor = Duration(seconds: 1);

  @override
  State<ImpressionTracker> createState() => _ImpressionTrackerState();
}

class _ImpressionTrackerState extends State<ImpressionTracker> {
  late final Key _key = UniqueKey();
  Timer? _timer;

  void _visibility(VisibilityInfo info) {
    if (info.visibleFraction >= 0.5) {
      _timer ??= Timer(ImpressionTracker.visibleFor, _record);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _record() {
    _timer = null;
    if (!mounted) return;
    if (ImpressionScope.of(context).firstTime(widget.story)) {
      unawaited(AnalyticsQueue.instance
          .trackContent('article_impression', widget.story));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AnalyticsQueue.contentIdOf(widget.story) == null) return widget.child;
    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: _visibility,
      child: widget.child,
    );
  }
}

// --- Reading -----------------------------------------------------------------

/// A story detail screen's reading: `article_open` once shown, scroll
/// milestones (25 / 50 / 75 / 100), `read_completion` at 90 %, and the active
/// reading time when the screen closes.
///
/// Reading time counts only while the screen is on top, the app is in the
/// foreground and the reader touched or scrolled within [idleAfter].
class ReadingTracker with WidgetsBindingObserver {
  ReadingTracker(this.story, {bool Function()? isOnTop})
      : _isOnTop = isOnTop ?? (() => true);

  /// Replaced by the full story once the detail loads (see [updateStory]).
  NewsArticle story;
  final bool Function() _isOnTop;

  static const milestones = [25, 50, 75, 100];
  static const completionAt = 90;
  static const idleAfter = Duration(seconds: 60);

  final Set<int> _sentMilestones = {};
  int _maxDepth = 0;
  bool _opened = false;
  bool _openSent = false;
  bool _completed = false;
  bool _foreground = true;
  int _activeSeconds = 0;
  DateTime _lastActivity = DateTime.now();
  Timer? _clock;

  int get activeSeconds => _activeSeconds;
  int get maxDepth => _maxDepth;

  /// The screen is displayed.
  void opened() {
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addObserver(this);
    _sendOpen();
    if (!_inWidgetTest) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }

  void _sendOpen() {
    if (_openSent || AnalyticsQueue.contentIdOf(story) == null) return;
    _openSent = true;
    unawaited(AnalyticsQueue.instance.trackContent('article_open', story));
  }

  /// The full story arrived: a story opened from a link may have had only a
  /// slug, and analytics need its UUID.
  void updateStory(NewsArticle full) {
    story = full;
    if (_opened) _sendOpen();
  }

  /// A touch or scroll: the reader is active.
  void activity() => _lastActivity = DateTime.now();

  /// One second passed.
  @visibleForTesting
  void tick({DateTime? now}) {
    final t = now ?? DateTime.now();
    if (_foreground && _isOnTop() && t.difference(_lastActivity) <= idleAfter) {
      _activeSeconds++;
    }
    _maybeComplete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) activity();
  }

  /// How far down the story the reader is, 0–100.
  void scrolledTo(int percent) {
    final p = percent.clamp(0, 100);
    activity();
    if (p <= _maxDepth) return;
    _maxDepth = p;
    for (final m in milestones) {
      if (p >= m && _sentMilestones.add(m)) {
        unawaited(AnalyticsQueue.instance
            .trackContent('scroll_depth', story, scrollDepth: m));
      }
    }
    _maybeComplete();
  }

  void _maybeComplete() {
    // Reached 90 % — and actually spent a moment on it (a short story that
    // fits on one screen is "at 100 %" the instant it opens).
    if (_completed || _maxDepth < completionAt || _activeSeconds < 3) return;
    _completed = true;
    unawaited(AnalyticsQueue.instance.trackContent('read_completion', story,
        dwellSeconds: _activeSeconds, scrollDepth: _maxDepth));
  }

  /// The screen closes: the reading time.
  void closed() {
    _clock?.cancel();
    if (!_opened) return;
    WidgetsBinding.instance.removeObserver(this);
    if (_activeSeconds > 0) {
      unawaited(AnalyticsQueue.instance.trackContent('scroll_depth', story,
          dwellSeconds: _activeSeconds, scrollDepth: _maxDepth));
    }
  }
}

// --- Video -------------------------------------------------------------------

/// Watches one playback of [story]'s video: `video_start` when it really
/// plays, `video_progress` every [interval] of watched time and
/// `video_complete` at 90 %. Watched time is clock time while playing, so
/// pauses, buffering, the background and skipped-over parts never count;
/// each event carries only the time watched since the previous one.
class VideoWatchTracker with WidgetsBindingObserver {
  VideoWatchTracker(this.story, this.controller, {required this.source}) {
    controller.addListener(_onState);
    WidgetsBinding.instance.addObserver(this);
    _onState();
  }

  final NewsArticle story;
  final VideoPlaybackController controller;

  /// `youtube` or `s3`.
  final String source;

  static const interval = Duration(seconds: 15);
  static const completeAt = 0.9;

  bool _started = false;
  bool _completed = false;
  bool _foreground = true;
  bool _disposed = false;
  DateTime? _playingSince;
  Duration _sinceLastEvent = Duration.zero;
  Duration _watched = Duration.zero;
  Timer? _tick;

  bool get _playing =>
      _foreground && !controller.isDisposed && controller.value.isPlaying;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _onState();
  }

  void _onState() {
    if (_disposed) return;
    if (_playing) {
      if (!_started) {
        _started = true;
        unawaited(AnalyticsQueue.instance
            .trackContent('video_start', story, metadata: {
          if (_durationSeconds > 0) 'duration_seconds': _durationSeconds,
          'source': source,
        }));
      }
      _playingSince ??= DateTime.now();
      if (!_inWidgetTest) {
        _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => advance());
      }
    } else {
      advance();
      _playingSince = null;
      _tick?.cancel();
      _tick = null;
      if (!controller.isDisposed && controller.value.isCompleted) {
        _complete();
      }
    }
  }

  int get _durationSeconds =>
      controller.isDisposed ? 0 : controller.value.duration.inSeconds;

  /// The position: the player's when it reports one (YouTube does not),
  /// else the time watched.
  int get _positionSeconds {
    final reported =
        controller.isDisposed ? 0 : controller.value.position.inSeconds;
    final p = reported > 0 ? reported : _watched.inSeconds;
    final d = _durationSeconds;
    return d > 0 ? p.clamp(0, d) : p;
  }

  int get _percent {
    final d = _durationSeconds;
    return d > 0 ? (_positionSeconds * 100 / d).round().clamp(0, 100) : 0;
  }

  Map<String, dynamic> get _where => {
        'position_seconds': _positionSeconds,
        if (_durationSeconds > 0) 'duration_seconds': _durationSeconds,
        if (_durationSeconds > 0) 'progress_percent': _percent,
        'source': source,
      };

  /// Adds the time played since the last call.
  @visibleForTesting
  void advance({DateTime? now}) {
    final since = _playingSince;
    if (since == null) return;
    final t = now ?? DateTime.now();
    var d = t.difference(since);
    // A long gap means the phone slept; that is not watching.
    if (d > const Duration(seconds: 5)) d = const Duration(seconds: 1);
    if (d.isNegative) d = Duration.zero;
    _playingSince = t;
    _sinceLastEvent += d;
    _watched += d;
    if (_sinceLastEvent >= interval && !_completed) {
      final dwell = _sinceLastEvent.inSeconds;
      _sinceLastEvent -= Duration(seconds: dwell);
      unawaited(AnalyticsQueue.instance.trackContent('video_progress', story,
          dwellSeconds: dwell, metadata: _where));
    }
    final dur = _durationSeconds;
    if (dur > 0 && _positionSeconds >= dur * completeAt) _complete();
  }

  void _complete() {
    if (_completed || !_started) return;
    _completed = true;
    final dwell = _sinceLastEvent.inSeconds;
    _sinceLastEvent = Duration.zero;
    unawaited(AnalyticsQueue.instance.trackContent('video_complete', story,
        dwellSeconds: dwell, metadata: _where));
  }

  /// Playback ends (stopped, swiped away, screen closed): the watched time
  /// not yet reported goes out as a last progress event.
  void dispose() {
    if (_disposed) return;
    advance();
    _disposed = true;
    _tick?.cancel();
    controller.removeListener(_onState);
    WidgetsBinding.instance.removeObserver(this);
    final rest = _sinceLastEvent.inSeconds;
    if (_started && !_completed && rest >= 1) {
      unawaited(AnalyticsQueue.instance.trackContent('video_progress', story,
          dwellSeconds: rest, metadata: _where));
    }
  }
}
