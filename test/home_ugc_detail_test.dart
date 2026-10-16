import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/state/app_state.dart';

class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    calls.add(o);
    return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'id': 'sub-1',
            'title': 'Wire theft',
            'description': 'Full post text',
            'district': 'Vikarabad',
            'state': 'Telangana',
          },
          'meta': {},
          'errors': null,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

/// A citizen post as GET /api/v1/feed/home/ sends it: no coverage_level.
Map<String, dynamic> _homeUgc() => {
      'id': '9a552bbe',
      'type': 'ugc',
      'title': 'వ్యవసాయ పొలాల్లో విద్యుత్ వైర్ల చోరీ',
      'summary': 'నవాబ్‌పేట: ...',
      'district': 'Vikarabad',
      'state': 'Telangana',
      'source': 'USER_UPLOAD',
      'metadata': {'source_id': '9a552bbe'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home cards show the real place, not "India / Global"', () {
    test('a citizen post without coverage_level takes its place', () {
      expect(NewsArticle.fromJson(_homeUgc()).coverageLevel, 'district');
      expect(
          NewsArticle.fromJson({..._homeUgc(), 'village': 'Pulumamidi'})
              .coverageLevel,
          'village');
    });

    test('coverage_level inside metadata is read (desk articles on Home)', () {
      final a = NewsArticle.fromJson({
        'id': 'a1',
        'type': 'article',
        'title': 't',
        'metadata': {'slug': 's', 'coverage_level': 'state'},
      });
      expect(a.coverageLevel, 'state');
    });

    test('a desk article with no coverage still reads as global', () {
      final a = NewsArticle.fromJson(
          {'id': 'a1', 'type': 'article', 'title': 't', 'district': 'X'});
      expect(a.coverageLevel, 'global');
    });
  });

  group('citizen post detail carries the reader\'s place', () {
    late _Recorder rec;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      rec = _Recorder();
      ApiClient.instance.dio.httpClientAdapter = rec;
      AppState.instance
        ..hasValidLocation = true
        ..stateName = 'Telangana'
        ..district = 'Vikarabad'
        ..subdistrict = ''
        ..village = '';
    });
    tearDown(() => AppState.instance
      ..hasValidLocation = false
      ..district = 'Hyderabad');

    test('GET /ugc/{id}/ sends state and district', () async {
      // Without them the backend answered 404 for area posts the feed showed.
      final post = await ApiService.instance.getUgcDetail('sub-1');
      final call = rec.calls.single;
      expect(call.path, '/api/v1/ugc/sub-1/');
      expect(call.queryParameters['state'], 'Telangana');
      expect(call.queryParameters['district'], 'Vikarabad');
      expect(call.queryParameters.containsKey('village'), isFalse);
      expect(post.title, 'Wire theft');
    });
  });

  test('the detail screen hides the error when the post text is shown', () {
    final src = File('lib/screens/news_detail_screen.dart').readAsStringSync();
    expect(src, contains('else if (_detailError != null && !_hasFullText)'));
    expect(src, contains('(_isUgc && article.summary.trim().isNotEmpty)'));
  });
}
