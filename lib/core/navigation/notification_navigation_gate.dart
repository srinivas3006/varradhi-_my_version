import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../models/notification_target.dart';

/// Event-based navigation readiness gate.
///
/// Solves cold-start / terminated-launch race conditions where a push notification
/// arrives before the root [HomeScreen] is mounted. Holds the target safely and consumes
/// it exactly once when the navigation tree is fully established.
class NotificationNavigationGate {
  NotificationNavigationGate._();
  static final NotificationNavigationGate instance = NotificationNavigationGate._();

  NotificationTarget? _pendingTarget;
  bool _isNavigationReady = false;
  bool _isDispatching = false;

  /// Kept from [onNavigationReady] so a target arriving *after* the tree is
  /// ready can still be dispatched.
  BuildContext? _readyContext;
  Future<void> Function(NotificationTarget, BuildContext)? _dispatcher;

  String? _lastDispatchedKey;
  DateTime? _lastDispatchedTime;
  static const Duration _dedupWindow = Duration(seconds: 2);

  bool get hasPendingTarget => _pendingTarget != null;
  NotificationTarget? get pendingTarget => _pendingTarget;
  bool get isNavigationReady => _isNavigationReady;
  bool get isDispatching => _isDispatching;

  /// Holds a target until the navigation tree is ready, or dispatches it
  /// immediately if it already is.
  ///
  /// The immediate path matters on cold start: getInitialMessage() is awaited
  /// inside the background init that runs after runApp, so the target
  /// routinely arrives *after* HomeScreen has already called
  /// onNavigationReady and found nothing pending. Storing it and waiting for
  /// a second onNavigationReady that never comes is why a tapped
  /// notification left the reader sitting on Home.
  void setPendingTarget(NotificationTarget target) {
    if (target.type == NotificationTargetType.unknown) {
      debugPrint('[NotificationGate] target unknown, nothing to navigate to');
      return;
    }

    final context = _readyContext;
    final dispatch = _dispatcher;
    if (_isNavigationReady && dispatch != null && context != null && context.mounted) {
      debugPrint('[NotificationGate] navigation already ready, '
          'dispatching ${target.type.name} immediately');
      _pendingTarget = null;
      // Dispatched directly, not via addPostFrameCallback: the tree is
      // already built (that is what _isNavigationReady means), and this is
      // called from an async messaging callback rather than during a build,
      // so there is no frame to wait for — and waiting for one that is never
      // scheduled is how the target got stranded in the first place.
      unawaited(dispatch(target, context));
      return;
    }

    debugPrint('[NotificationGate] holding ${target.type.name} '
        'until navigation is ready');
    _pendingTarget = target;
  }

  /// Consumes and clears the pending target.
  NotificationTarget? consumePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }

  /// Returns true if this target should be processed, or false if it is a duplicate
  /// of an in-flight or recently dispatched target within the deduplication window.
  bool acquireDispatchLock(NotificationTarget target) {
    if (_isDispatching) {
      debugPrint('[NotificationNavigationGate] Target rejected: already dispatching');
      return false;
    }

    final key = '${target.type.name}:${target.identifier ?? target.screenName ?? ''}';
    final now = DateTime.now();

    if (_lastDispatchedKey == key &&
        _lastDispatchedTime != null &&
        now.difference(_lastDispatchedTime!) < _dedupWindow) {
      debugPrint('[NotificationNavigationGate] Duplicate target suppressed: $key');
      return false;
    }

    _isDispatching = true;
    _lastDispatchedKey = key;
    _lastDispatchedTime = now;
    return true;
  }

  /// Releases the dispatch lock after navigation is complete or failed.
  void releaseDispatchLock() {
    _isDispatching = false;
  }

  /// Invoked by [HomeScreen] once it has mounted as the root shell.
  /// Dispatches any pending target exactly once.
  void onNavigationReady(
    BuildContext context,
    Future<void> Function(NotificationTarget target, BuildContext context) onDispatch,
  ) {
    _isNavigationReady = true;
    _readyContext = context;
    _dispatcher = onDispatch;

    final target = consumePendingTarget();
    debugPrint('[NotificationGate] navigation ready; '
        'pending=${target?.type.name ?? 'none'}');
    if (target != null && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (context.mounted) {
          await onDispatch(target, context);
        }
      });
    }
  }

  /// Resets state (useful for tests or app logout).
  @visibleForTesting
  void reset() {
    _pendingTarget = null;
    _isNavigationReady = false;
    _isDispatching = false;
    _lastDispatchedKey = null;
    _lastDispatchedTime = null;
    _readyContext = null;
    _dispatcher = null;
  }
}
