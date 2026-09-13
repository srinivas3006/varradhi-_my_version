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

  String? _lastDispatchedKey;
  DateTime? _lastDispatchedTime;
  static const Duration _dedupWindow = Duration(seconds: 2);

  bool get hasPendingTarget => _pendingTarget != null;
  NotificationTarget? get pendingTarget => _pendingTarget;
  bool get isNavigationReady => _isNavigationReady;
  bool get isDispatching => _isDispatching;

  /// Sets the pending target during cold launch.
  void setPendingTarget(NotificationTarget target) {
    if (target.type == NotificationTargetType.unknown) return;
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

    final target = consumePendingTarget();
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
  }
}
