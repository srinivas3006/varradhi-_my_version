import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Identity & Installation Secret Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'deviceId': 'test_stable_device_12345',
        'installation_secret': 'test_secret_abcde',
      });
    });

    test('AppState preserves existing deviceId and installationSecret from storage', () async {
      final state = AppState.instance;
      await state.init();

      expect(state.deviceId, equals('test_stable_device_12345'));
      expect(state.installationSecret, equals('test_secret_abcde'));
    });

    test('regenerateDeviceId does not mutate stable deviceId', () async {
      final state = AppState.instance;
      await state.init();

      final originalId = state.deviceId;
      final returnedId = await state.regenerateDeviceId();

      expect(returnedId, equals(originalId));
      expect(state.deviceId, equals(originalId));
      expect(state.installationSecret, equals('test_secret_abcde'));
    });

    test('Updating installationSecret persists across changes', () async {
      final state = AppState.instance;
      await state.setInstallationSecret('new_confirmed_secret_999');

      expect(state.installationSecret, equals('new_confirmed_secret_999'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('installation_secret'), equals('new_confirmed_secret_999'));
    });
  });
}
