import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Covers the cooldown policy behind LocationPermissionCoordinator
/// (see lib/services/location_permission_coordinator.dart). The coordinator
/// itself is a thin UI wrapper around Geolocator + these AppState rules, so
/// the rules are what's worth pinning down: they decide whether Spotlight,
/// Local and Post are allowed to interrupt the reader with a location ask.
void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    final state = AppState.instance;
    state.hasValidLocation = false;
    state.locationPrompted = false;
    state.locationPromptShownCount = 0;
    state.locationPromptLastShownAtMs = null;
    state.locationPromptDismissedAtMs = null;
    state.locationPermissionDeniedAtMs = null;
    state.locationPermissionDeniedForever = false;
  });

  group('AppState.shouldAutoPromptLocation', () {
    test('allows an automatic prompt with a clean slate', () {
      expect(AppState.instance.shouldAutoPromptLocation(), isTrue);
    });

    test('never auto-prompts once a valid location is known', () {
      AppState.instance.hasValidLocation = true;
      expect(AppState.instance.shouldAutoPromptLocation(), isFalse);
    });

    test('never auto-prompts after a permanent denial', () {
      AppState.instance.markLocationPermissionDenied(forever: true);
      expect(AppState.instance.locationPermissionDeniedForever, isTrue);
      expect(AppState.instance.shouldAutoPromptLocation(), isFalse);
    });

    test('caps automatic prompts at 2 total, regardless of cooldowns', () {
      final now = DateTime(2026, 1, 1);
      AppState.instance
        ..locationPromptShownCount = 2
        ..locationPromptLastShownAtMs =
            now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      expect(AppState.instance.shouldAutoPromptLocation(now: now), isFalse);
    });

    test('"Maybe later" enforces a 3-day cooldown', () {
      final now = DateTime(2026, 1, 10);
      AppState.instance.markLocationPromptDismissed();
      AppState.instance.locationPromptDismissedAtMs =
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      expect(AppState.instance.shouldAutoPromptLocation(now: now), isFalse);

      final laterEnough = now.add(const Duration(days: 3));
      expect(
        AppState.instance.shouldAutoPromptLocation(now: laterEnough),
        isTrue,
      );
    });

    test('a regular Android denial enforces a 7-day cooldown', () {
      final now = DateTime(2026, 2, 1);
      AppState.instance.markLocationPermissionDenied();
      AppState.instance.locationPermissionDeniedAtMs =
          now.subtract(const Duration(days: 5)).millisecondsSinceEpoch;
      expect(AppState.instance.shouldAutoPromptLocation(now: now), isFalse);

      final laterEnough = now.add(const Duration(days: 7));
      expect(
        AppState.instance.shouldAutoPromptLocation(now: laterEnough),
        isTrue,
      );
    });

    test('back-to-back prompts respect a 12-hour minimum spacing', () {
      final now = DateTime(2026, 3, 1);
      AppState.instance.locationPromptLastShownAtMs =
          now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      expect(AppState.instance.shouldAutoPromptLocation(now: now), isFalse);

      final laterEnough = now.add(const Duration(hours: 12));
      expect(
        AppState.instance.shouldAutoPromptLocation(now: laterEnough),
        isTrue,
      );
    });
  });

  group('AppState location prompt bookkeeping', () {
    test('markLocationPrompted increments count and timestamps it', () {
      AppState.instance.markLocationPrompted();
      expect(AppState.instance.locationPrompted, isTrue);
      expect(AppState.instance.locationPromptShownCount, equals(1));
      expect(AppState.instance.locationPromptLastShownAtMs, isNotNull);
    });

    test('markLocationPermissionDenied(forever: true) sets the flag', () {
      AppState.instance.markLocationPermissionDenied(forever: true);
      expect(AppState.instance.locationPermissionDeniedForever, isTrue);
      expect(AppState.instance.locationPermissionDeniedAtMs, isNotNull);
    });
  });
}
