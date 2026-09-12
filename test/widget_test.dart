import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/main.dart';

class WidgetTestMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'data': [], 'meta': {}, 'errors': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return mockSecureStorage[methodCall.arguments?['key']];
      } else if (methodCall.method == 'write') {
        final key = methodCall.arguments?['key'] as String?;
        final value = methodCall.arguments?['value'] as String?;
        if (key != null && value != null) {
          mockSecureStorage[key] = value;
        }
        return null;
      } else if (methodCall.method == 'delete') {
        mockSecureStorage.remove(methodCall.arguments?['key']);
        return null;
      } else if (methodCall.method == 'deleteAll') {
        mockSecureStorage.clear();
        return null;
      }
      return null;
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = WidgetTestMockAdapter();
  });

  testWidgets('App smoke test - boots and renders MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const Way2NewsCloneApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    // Complete splash screen delay and transition
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 600));
    // Complete spotlight overlay timer (4s)
    await tester.pump(const Duration(seconds: 5));
  });
}
