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

  bool get hasPendingTarget => _pendingTarget != null;
  NotificationTarget? get pendingTarget => _pendingTarget;
  bool get isNavigationReady => _isNavigationReady;

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

  /// Invoked by [HomeScreen] once it has mounted as the root shell.
  /// Dispatches any pending target exactly once.
  void onNavigationReady(
    BuildContext context,
    void Function(NotificationTarget target, BuildContext context) onDispatch,
  ) {
    _isNavigationReady = true;

    final target = consumePendingTarget();
    if (target != null && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onDispatch(target, context);
        }
      });
    }
  }

  /// Resets state (useful for tests or app logout).
  @visibleForTesting
  void reset() {
    _pendingTarget = null;
    _isNavigationReady = false;
  }
}
