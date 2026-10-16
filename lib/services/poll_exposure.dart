import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/poll.dart';

/// How often a reader is shown the same poll.
///
/// A poll is offered at most [maxViews] times (counted once per app session),
/// and not again once the reader has voted. In the session where a poll is
/// seen or voted on it stays put, so the results do not vanish the moment
/// the vote lands. The deep-linked poll screen is not limited.
class PollExposure {
  PollExposure._();
  static final PollExposure instance = PollExposure._();

  static const int maxViews = 2;

  @visibleForTesting
  static const String viewsKey = 'poll_views_v1';
  @visibleForTesting
  static const String votedKey = 'poll_voted_v1';

  final Map<String, int> _views = {};
  final Set<String> _voted = {};

  /// Polls counted (or voted on) during this app session.
  final Set<String> _thisSession = {};

  Future<void>? _loading;

  /// Loads the saved counts once; safe to await from anywhere.
  Future<void> ready() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(viewsKey);
      if (raw != null) {
        final map = jsonDecode(raw);
        if (map is Map) {
          map.forEach((k, v) {
            if (v is num) _views[k.toString()] = v.toInt();
          });
        }
      }
      _voted.addAll(prefs.getStringList(votedKey) ?? const []);
    } catch (_) {}
  }

  /// Whether [poll] may be shown in a feed now.
  bool shouldShow(Poll poll) {
    final id = poll.id;
    if (id.isEmpty) return true;
    if (_thisSession.contains(id)) return true;
    if (_voted.contains(id) || poll.selectedOption != null) return false;
    return (_views[id] ?? 0) < maxViews;
  }

  /// The polls from [polls] that may be shown now, in the same order.
  List<Poll> eligible(Iterable<Poll> polls) => polls.where(shouldShow).toList();

  /// Count one view of [pollId] — at most once per app session.
  Future<void> markShown(String pollId) async {
    if (pollId.isEmpty || !_thisSession.add(pollId)) return;
    _views[pollId] = (_views[pollId] ?? 0) + 1;
    await _save();
  }

  /// The reader voted: never offered again after this session.
  Future<void> markVoted(String pollId) async {
    if (pollId.isEmpty) return;
    _thisSession.add(pollId);
    if (_voted.add(pollId)) await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Bounded so the map cannot grow forever.
      if (_views.length > 300) {
        final keep = _views.keys.toList().sublist(_views.length - 300);
        _views.removeWhere((k, _) => !keep.contains(k));
      }
      await prefs.setString(viewsKey, jsonEncode(_views));
      await prefs.setStringList(votedKey, _voted.toList());
    } catch (_) {}
  }

  /// Simulates a fresh app start (tests).
  @visibleForTesting
  void resetForTest() {
    _views.clear();
    _voted.clear();
    _thisSession.clear();
    _loading = null;
  }

  /// Ends the session without clearing what was saved (tests).
  @visibleForTesting
  void newSessionForTest() {
    _thisSession.clear();
    _loading = null;
    _views.clear();
    _voted.clear();
  }
}
