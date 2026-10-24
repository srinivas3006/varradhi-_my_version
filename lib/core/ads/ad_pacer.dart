import 'dart:async';

import 'package:flutter/widgets.dart';

/// One kind of ad that comes and goes instead of staying on screen.
class PacedSlot {
  const PacedSlot({
    required this.firstAfter,
    required this.every,
    required this.visibleFor,
  });

  /// Active use before the first appearance.
  final Duration firstAfter;

  /// Active use between the end of one appearance and the next.
  final Duration every;

  /// How long it stays once it appears.
  final Duration visibleFor;
}

/// Times the ads that should not sit on screen all the time.
///
/// Only *active* use counts: the app is in the foreground and the reader
/// scrolled or swiped within the last [idleAfter]. So a phone left open on
/// the table never fills up with ads, and a reader who keeps reading sees a
/// short appearance every few minutes, which then goes away on its own —
/// the way large news and social apps pace their ads.
///
/// Feed ads between stories are not paced here; they keep their place in
/// the feed. Paced:
///  * the bottom banner above the nav bar ([sticky]);
///  * the 3D / video corner ad ([floating3d]) — on every screen, every 2
///    minutes of use, in the next corner and the next 3D format each time.
class AdPacer extends ChangeNotifier with WidgetsBindingObserver {
  AdPacer._();
  static final AdPacer instance = AdPacer._();

  static const sticky = PacedSlot(
    firstAfter: Duration(minutes: 3),
    every: Duration(minutes: 2),
    visibleFor: Duration(seconds: 30),
  );

  static const floating3d = PacedSlot(
    firstAfter: Duration(minutes: 2),
    every: Duration(minutes: 2),
    visibleFor: Duration(seconds: 20),
  );

  /// No scroll or swipe for this long and the reader counts as idle.
  static const idleAfter = Duration(seconds: 45);

  Duration _active = Duration.zero;
  DateTime? _lastActivity;
  bool _foreground = true;
  Timer? _timer;

  final Map<PacedSlot, _SlotState> _slots = {
    sticky: _SlotState(sticky),
    floating3d: _SlotState(floating3d),
  };

  /// Which ad of the pool shows next time, so appearances rotate.
  int stickyRotation = 0;
  int floatingRotation = 0;

  Duration get activeTime => _active;
  bool get stickyVisible => _slots[sticky]!.visible;
  bool get floatingVisible => _slots[floating3d]!.visible;

  /// Starts the one-second clock and lifecycle tracking. Safe to call twice.
  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// A scroll, swipe or tap: the reader is using the app.
  void reportActivity([DateTime? now]) => _lastActivity = now ?? DateTime.now();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      // Leaving the app ends any appearance; it does not resume mid-way.
      var changed = false;
      for (final s in _slots.values) {
        changed |= s.hide();
      }
      if (changed) notifyListeners();
    }
  }

  /// Advances the clock by [step] (one second in the app).
  @visibleForTesting
  void tick({Duration step = const Duration(seconds: 1), DateTime? now}) {
    final t = now ?? DateTime.now();
    final last = _lastActivity;
    final engaged =
        _foreground && last != null && t.difference(last) <= idleAfter;
    var changed = false;
    if (engaged) _active += step;

    for (final s in _slots.values) {
      if (s.visible) {
        // Counts down in wall time once shown, so it always goes away.
        s.shownFor += step;
        if (s.shownFor >= s.slot.visibleFor) {
          s.hide();
          if (identical(s.slot, sticky)) stickyRotation++;
          if (identical(s.slot, floating3d)) floatingRotation++;
          changed = true;
        }
      } else if (engaged && _active >= s.dueAt) {
        s.show(_active);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// The reader closed it: hide now and wait a full period.
  void dismiss(PacedSlot slot) {
    final s = _slots[slot]!;
    if (s.hide()) {
      if (identical(slot, sticky)) stickyRotation++;
      if (identical(slot, floating3d)) floatingRotation++;
      notifyListeners();
    }
  }

  @visibleForTesting
  void resetForTest() {
    _active = Duration.zero;
    _lastActivity = null;
    _foreground = true;
    stickyRotation = 0;
    floatingRotation = 0;
    for (final s in _slots.values) {
      s.reset();
    }
  }
}

class _SlotState {
  _SlotState(this.slot) : dueAt = slot.firstAfter;

  final PacedSlot slot;
  Duration dueAt;
  bool visible = false;
  Duration shownFor = Duration.zero;
  Duration _shownAtActive = Duration.zero;

  void show(Duration active) {
    visible = true;
    shownFor = Duration.zero;
    _shownAtActive = active;
  }

  /// Returns whether it was visible.
  bool hide() {
    if (!visible) return false;
    visible = false;
    // Next appearance: a full period of active use after this one began.
    dueAt = _shownAtActive + slot.every;
    return true;
  }

  void reset() {
    dueAt = slot.firstAfter;
    visible = false;
    shownFor = Duration.zero;
    _shownAtActive = Duration.zero;
  }
}
