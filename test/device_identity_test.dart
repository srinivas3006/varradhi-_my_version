import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStore = <String, String>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final key = call.arguments?['key'] as String?;
      switch (call.method) {
        case 'read':
          return secureStore[key];
        case 'write':
          final value = call.arguments?['value'] as String?;
          if (key != null && value != null) secureStore[key] = value;
          return null;
        case 'delete':
          secureStore.remove(key);
          return null;
        case 'deleteAll':
          secureStore.clear();
          return null;
      }
      return null;
    });
  });

  group('Device Identity & Installation Secret Tests', () {
    setUp(() async {
      secureStore.clear();
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

    test('a legacy plaintext secret migrates to secure storage and is purged', () async {
      final state = AppState.instance;
      await state.init();

      expect(secureStore['installation_secret'], equals('test_secret_abcde'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('installation_secret'), isNull);
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

    test('Updating installationSecret persists to secure storage, not prefs', () async {
      final state = AppState.instance;
      await state.setInstallationSecret('new_confirmed_secret_999');

      expect(state.installationSecret, equals('new_confirmed_secret_999'));
      expect(secureStore['installation_secret'],
          equals('new_confirmed_secret_999'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('installation_secret'), isNull);
    });
  });
}
