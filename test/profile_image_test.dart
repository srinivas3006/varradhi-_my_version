import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/services/api_service.dart';
import 'package:way2news_clone/state/app_state.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
          Future<void>? __) =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> b, int s) =>
    ResponseBody.fromString(jsonEncode(b), s, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = AppState.instance;
  late File avatar;

  setUpAll(() {
    avatar = File('${Directory.systemTemp.path}/avatar_test.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state.profileImageUrl = null;
    state.profileImagePath = null;
    state.userName = 'Old Name';
  });

  void serve(Future<ResponseBody> Function(RequestOptions) h) {
    ApiClient.instance.dio.httpClientAdapter = _Adapter(h);
  }

  group('the avatar goes through the existing PATCH endpoint', () {
    test('it PATCHes /auth/me/ as multipart', () async {
      String? method, path;
      Object? body;
      serve((o) async {
        method = o.method;
        path = o.path;
        body = o.data;
        return _json({
          'data': {
            'full_name': 'New Name',
            'profile_image': 'https://cdn.example.com/a.jpg',
          }
        }, 200);
      });

      final ok = await state.updateProfile(
          name: 'New Name', imagePath: avatar.path);

      expect(ok, isTrue);
      expect(method, 'PATCH');
      expect(path, '/api/v1/auth/me/');
      expect(body, isA<FormData>(),
          reason: 'an actual file needs multipart/form-data');
    });

    test('the multipart body carries profile_image and full_name', () async {
      FormData? sent;
      serve((o) async {
        sent = o.data as FormData;
        return _json({'data': {'profile_image': 'https://cdn.x/a.jpg'}}, 200);
      });

      await state.updateProfile(name: 'N', imagePath: avatar.path);

      expect(sent!.files.map((e) => e.key), contains('profile_image'));
      expect(sent!.fields.map((e) => e.key), contains('full_name'));
    });

    test('a name-only save stays JSON, not multipart', () async {
      Object? body;
      serve((o) async {
        body = o.data;
        return _json({'data': {'full_name': 'N'}}, 200);
      });

      await state.updateProfile(name: 'N');
      expect(body, isNot(isA<FormData>()));
      expect(body, {'full_name': 'N'});
    });
  });

  group('the server URL becomes canonical', () {
    test('the returned profile_image updates AppState', () async {
      serve((o) async => _json({
            'data': {'profile_image': 'https://cdn.example.com/me.png'}
          }, 200));

      await state.updateProfile(name: 'N', imagePath: avatar.path);

      expect(state.profileImageUrl, 'https://cdn.example.com/me.png');
      expect(state.profileImagePath, isNull,
          reason: 'the local copy is superseded by the uploaded URL');
    });

    test('it survives a restart via persisted prefs', () async {
      serve((o) async => _json({
            'data': {'profile_image': 'https://cdn.example.com/me.png'}
          }, 200));

      await state.updateProfile(name: 'N', imagePath: avatar.path);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profileImageUrl'),
          'https://cdn.example.com/me.png');
    });
  });

  group('a failed upload keeps the previous avatar', () {
    test('a 500 restores the old url and name', () async {
      state.profileImageUrl = 'https://cdn.example.com/old.png';
      serve((o) async => _json({'errors': {'message': 'nope'}}, 500));

      final ok = await state.updateProfile(
          name: 'New Name', imagePath: avatar.path);

      expect(ok, isFalse);
      expect(state.profileImageUrl, 'https://cdn.example.com/old.png',
          reason: 'a rejected upload must not erase the existing avatar');
      expect(state.userName, 'Old Name');
    });

    test('a network failure restores state too', () async {
      state.profileImageUrl = 'https://cdn.example.com/old.png';
      serve((o) async => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError));

      expect(
        await state.updateProfile(name: 'X', imagePath: avatar.path),
        isFalse,
      );
      expect(state.profileImageUrl, 'https://cdn.example.com/old.png');
    });
  });

  group('the avatar is read back from /auth/me/', () {
    test('refreshRolesFromServer picks up profile_image', () {
      final src = File('lib/state/app_state.dart').readAsStringSync();
      final fn =
          src.substring(src.indexOf('Future<void> refreshRolesFromServer'));
      expect(fn, contains("me['profile_image']"));
      expect(fn, contains('profileImageUrl = serverImage'));
    });

    test('updateProfile takes an image file rather than a path string', () {
      final api = File('lib/services/api_service.dart').readAsStringSync();
      final fn = api.substring(api.indexOf('Future<Map<String, dynamic>> updateProfile'));
      expect(fn.substring(0, 900), contains('File? imageFile'));
      expect(fn.substring(0, 900), contains('MultipartFile.fromFile'));
    });
  });
}
