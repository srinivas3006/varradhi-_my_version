import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state.likedItemIds.clear();
    state.dislikedItemIds.clear();
  });

  void serve(Future<ResponseBody> Function(RequestOptions) h) {
    ApiClient.instance.dio.httpClientAdapter = _Adapter(h);
  }

  group('every like path reaches the server', () {
    test('toggleLike PUTs the reaction', () async {
      String? method, path;
      Object? body;
      serve((o) async {
        method = o.method;
        path = o.path;
        body = o.data;
        return _json({'data': {'like_count': 1}}, 200);
      });

      await state.toggleLike('a1');

      // Regression: toggleLike only wrote the local set, so a double-tap or a
      // video-tab like changed the icon and was gone on the next refresh.
      expect(method, 'PUT');
      expect(path, '/api/v1/articles/a1/reaction/');
      expect(body, {'reaction_type': 'like'});
      expect(state.isLiked('a1'), isTrue);
    });

    test('un-liking sends a DELETE', () async {
      String? method;
      serve((o) async {
        method = o.method;
        return _json({'data': {'like_count': 0}}, 200);
      });

      state.setReaction('a1', 'like');
      await state.toggleLike('a1');

      expect(method, 'DELETE');
      expect(state.isLiked('a1'), isFalse);
    });

    test('toggleDislike reaches the server too', () async {
      Object? body;
      serve((o) async {
        body = o.data;
        return _json({'data': {'like_count': 0}}, 200);
      });

      await state.toggleDislike('a1');
      expect(body, {'reaction_type': 'dislike'});
      expect(state.isDisliked('a1'), isTrue);
    });
  });

  group('a rejected reaction is rolled back', () {
    test('a failed like does not leave the icon lit', () async {
      serve((o) async => _json({'errors': {'message': 'nope'}}, 500));

      await state.toggleLike('a1');

      expect(state.isLiked('a1'), isFalse,
          reason: 'the icon must not claim a like the server refused');
    });

    test('a failed un-like restores the like', () async {
      state.setReaction('a1', 'like');
      serve((o) async => _json({'errors': {'message': 'nope'}}, 500));

      await state.toggleLike('a1');

      expect(state.isLiked('a1'), isTrue);
    });

    test('a failed dislike restores the previous reaction', () async {
      state.setReaction('a1', 'like');
      serve((o) async => _json({'errors': {'message': 'nope'}}, 500));

      await state.toggleDislike('a1');

      expect(state.isLiked('a1'), isTrue,
          reason: 'the earlier like must come back, not just clear');
      expect(state.isDisliked('a1'), isFalse);
    });

    test('a network failure rolls back too', () async {
      serve((o) async => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError));

      await state.toggleLike('a1');
      expect(state.isLiked('a1'), isFalse);
    });
  });

  group('like and dislike stay mutually exclusive through the toggles', () {
    test('disliking a liked item clears the like', () async {
      serve((o) async => _json({'data': {'like_count': 0}}, 200));

      await state.toggleLike('a1');
      await state.toggleDislike('a1');

      expect(state.isDisliked('a1'), isTrue);
      expect(state.isLiked('a1'), isFalse);
      expect(state.getReaction('a1'), 'dislike');
    });
  });

  group('there is one reaction path, not two', () {
    test('toggleLike syncs rather than only writing local state', () {
      final src = File('lib/state/app_state.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('Future<void> toggleLike('));
      expect(fn.substring(0, 600), contains('_syncReaction'));
    });

    test('the sync uses the existing reaction endpoint', () {
      final src = File('lib/state/app_state.dart').readAsStringSync();
      expect(src, contains('postArticleReaction'));
    });
  });
}
