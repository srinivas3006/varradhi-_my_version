import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// AppNavigatorObserver logs route changes during development and tracks
/// navigation stack depth without logging any sensitive parameters.
class AppNavigatorObserver extends NavigatorObserver {
  static final AppNavigatorObserver instance = AppNavigatorObserver._internal();

  AppNavigatorObserver._internal();

  int _stackDepth = 0;
  String? _currentRouteName;

  int get stackDepth => _stackDepth;
  String? get currentRouteName => _currentRouteName;

  String _getRouteName(Route<dynamic>? route) {
    if (route == null) return 'null';
    return route.settings.name ?? route.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _stackDepth++;
    _currentRouteName = _getRouteName(route);
    if (kDebugMode) {
      debugPrint('[NavObserver] PUSH: $_currentRouteName (depth: $_stackDepth, previous: ${_getRouteName(previousRoute)})');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_stackDepth > 0) _stackDepth--;
    _currentRouteName = _getRouteName(previousRoute);
    if (kDebugMode) {
      debugPrint('[NavObserver] POP: ${_getRouteName(route)} (depth: $_stackDepth, returnedTo: $_currentRouteName)');
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_stackDepth > 0) _stackDepth--;
    _currentRouteName = _getRouteName(previousRoute);
    if (kDebugMode) {
      debugPrint('[NavObserver] REMOVE: ${_getRouteName(route)} (depth: $_stackDepth)');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _currentRouteName = _getRouteName(newRoute);
    if (kDebugMode) {
      debugPrint('[NavObserver] REPLACE: ${_getRouteName(oldRoute)} -> $_currentRouteName (depth: $_stackDepth)');
    }
  }

  @visibleForTesting
  void reset() {
    _stackDepth = 0;
    _currentRouteName = null;
  }
}
