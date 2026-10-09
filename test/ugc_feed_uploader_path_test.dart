import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/repositories/ugc_repository.dart';

/// Serves the /ugc/feed/ reply exactly as production sent it on 2026-10-07.
class _UgcFeed implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    return ResponseBody.fromString(
      jsonEncode({
        'data': [
          {
            'id': '7cb89949',
            'type': 'ugc',
            'title': 'రూ.300 శ్రీవారి దర్శన టికెట్లు విడుదల',
            'description': 'తిరుమల : శ్రీవారి నవరాత్రి బ్రహ్మోత్సవాల',
            'language': 'te',
            'state': 'Telangana',
            'created_at': '2026-10-06T22:00:00+05:30',
            'source': 'USER_UPLOAD',
            'trust_level': 'VERIFIED_USER',
            'uploader': {
              'id': '2f4beca2',
              'display_name': 'Ramakrishna Sagar',
              'trust_level': 'VERIFIED_USER',
            },
          },
        ],
        'meta': {'next': null},
        'errors': null,
      }),
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

  // The exact path Spotlight uses for citizen posts.
  test('Spotlight citizen post shows the uploader, not USER_UPLOAD', () async {
    ApiClient.instance.dio.httpClientAdapter = _UgcFeed();
    final r = await UgcRepository.instance.getUgcFeed(scope: 'main');
    final post = r.data!.single;
    expect(post.byline, 'Ramakrishna Sagar');
    expect(post.authorName, isNot('USER_UPLOAD'));
  });
}
