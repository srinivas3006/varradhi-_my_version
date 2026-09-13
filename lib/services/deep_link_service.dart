import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/navigation/notification_deep_link_resolver.dart';
import '../core/navigation/notification_navigation_gate.dart';
import '../models/notification_target.dart';
import 'notification_service.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();
  static const MethodChannel _channel =
      MethodChannel('com.vaaradhi.vaaradhi/deep_links');

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        await handleUri(call.arguments?.toString());
      }
    });

    try {
      final initialUri = await _channel.invokeMethod<String>('getInitialLink');
      await handleUri(initialUri);
    } on PlatformException catch (e) {
      debugPrint('[DeepLinkService] Could not read initial link: $e');
    } on MissingPluginException {
      // Expected in widget tests and on platforms without the Android bridge.
    }
  }

  @visibleForTesting
  Future<void> handleUri(String? rawUri) async {
    final target = NotificationDeepLinkResolver.resolveFromUri(rawUri);
    if (target.type == NotificationTargetType.unknown) return;

    if (!NotificationNavigationGate.instance.isNavigationReady) {
      NotificationNavigationGate.instance.setPendingTarget(target);
      return;
    }

    await NotificationService.instance.navigateToTarget(target);
  }
}
