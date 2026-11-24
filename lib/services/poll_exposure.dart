import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/poll.dart';
import 'poll_context.dart';

/// How often a reader is shown the same poll.
///
/// A poll is offered at most [maxViews] times (counted once per app session).
/// The latest server response determines whether the reader has voted.
/// A card already seen this session stays in place after voting.
/// The deep-linked poll screen is not limited.
class PollExposure {
  PollExposure._();
  static final PollExposure instance = PollExposure._();

  static const int maxViews = 2;

  @visibleForTesting
  static const String viewsKey = 'poll_views_v2';
  final _stores = <String, _PollPacing>{};

  _PollPacing get _pacing {
    final reader = currentPollReader;
    final account = reader.account ?? reader.session;
    final scope = reader.authenticated
        ? (account == null ? null : 'account:$account')
        : (reader.device.isEmpty ? '' : 'installation:${reader.device}');
    return _stores.putIfAbsent(
        scope ?? 'session-only', () => _PollPacing(scope));
  }

  Future<void> ready() {
    final pacing = _pacing;
    return pacing.loading ??= _load(pacing);
  }

  Future<void> _load(_PollPacing pacing) async {
    if (pacing.scope == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(pacing.key(viewsKey));
      if (raw != null) {
        final map = jsonDecode(raw);
        if (map is Map) {
          map.forEach((k, v) {
            if (v is num) pacing.views[k.toString()] = v.toInt();
          });
        }
      }
    } catch (_) {}
  }

  bool shouldShow(Poll poll) {
    if (!poll.isActive) return false;
    final pacing = _pacing;
    if (pacing.thisSession.contains(poll.id)) return true;
    if (poll.hasVoted || poll.closed) return false;
    return (pacing.views[poll.id] ?? 0) < maxViews;
  }

  List<Poll> eligible(Iterable<Poll> polls) => polls.where(shouldShow).toList();

  Future<void> markShown(String pollId) async {
    if (pollId.isEmpty) return;
    final pacing = _pacing;
    await (pacing.loading ??= _load(pacing));
    if (!pacing.thisSession.add(pollId)) return;
    pacing.views[pollId] = (pacing.views[pollId] ?? 0) + 1;
    await _save(pacing);
  }

  Future<void> _save(_PollPacing pacing) async {
    if (pacing.scope == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pacing.views.length > 300) {
        final keep =
            pacing.views.keys.toList().sublist(pacing.views.length - 300);
        pacing.views.removeWhere((key, _) => !keep.contains(key));
      }
      await prefs.setString(pacing.key(viewsKey), jsonEncode(pacing.views));
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest() => _stores.clear();

  @visibleForTesting
  void newSessionForTest() => _stores.clear();
}

class _PollPacing {
  _PollPacing(this.scope);

  final String? scope;
  final views = <String, int>{};
  final thisSession = <String>{};
  Future<void>? loading;

  String key(String prefix) =>
      scope == '' ? prefix : '$prefix:${Uri.encodeComponent(scope!)}';
}
