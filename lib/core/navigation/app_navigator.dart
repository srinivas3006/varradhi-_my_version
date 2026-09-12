import 'package:flutter/material.dart';

/// AppNavigator provides debounced, safe navigation primitives that prevent
/// duplicate route stacking caused by rapid successive user taps.
class AppNavigator {
  AppNavigator._();

  static DateTime? _lastNavigationTime;
  static const Duration _debounceDuration = Duration(milliseconds: 375);

  /// Whether a navigation transition was initiated recently.
  static bool get isNavigating {
    if (_lastNavigationTime == null) return false;
    return DateTime.now().difference(_lastNavigationTime!) < _debounceDuration;
  }

  /// Pushes a [route] onto the [Navigator] associated with [context] only if
  /// not currently throttled by a recent navigation event.
  static Future<T?> pushSafe<T extends Object?>(
    BuildContext context,
    Route<T> route,
  ) async {
    if (!context.mounted) return null;
    if (isNavigating) {
      debugPrint('[AppNavigator] Duplicate push prevented: ${route.settings.name ?? route.runtimeType}');
      return null;
    }
    _lastNavigationTime = DateTime.now();

    try {
      if (!context.mounted) return null;
      return await Navigator.of(context).push<T>(route);
    } finally {
      // Allow new navigation after the debounce duration or route completion
      Future.delayed(_debounceDuration, () {
        if (_lastNavigationTime != null &&
            DateTime.now().difference(_lastNavigationTime!) >= _debounceDuration) {
          _lastNavigationTime = null;
        }
      });
    }
  }

  /// Replaces the current route with [newRoute] safely with debounce protection.
  static Future<T?> pushReplacementSafe<T extends Object?, TO extends Object?>(
    BuildContext context,
    Route<T> newRoute, {
    TO? result,
  }) async {
    if (!context.mounted) return null;
    if (isNavigating) {
      debugPrint('[AppNavigator] Duplicate pushReplacement prevented: ${newRoute.settings.name ?? newRoute.runtimeType}');
      return null;
    }
    _lastNavigationTime = DateTime.now();

    try {
      if (!context.mounted) return null;
      return await Navigator.of(context).pushReplacement<T, TO>(newRoute, result: result);
    } finally {
      Future.delayed(_debounceDuration, () {
        if (_lastNavigationTime != null &&
            DateTime.now().difference(_lastNavigationTime!) >= _debounceDuration) {
          _lastNavigationTime = null;
        }
      });
    }
  }

  /// Safely pops the top route of [context] if possible.
  static void popSafe<T extends Object?>(BuildContext context, [T? result]) {
    if (!context.mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop<T>(result);
    }
  }

  /// Resets debounce state (useful for tests).
  @visibleForTesting
  static void resetDebounce() {
    _lastNavigationTime = null;
  }
}
