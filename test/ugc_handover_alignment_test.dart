import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/errors/ugc_error.dart';
import 'package:vaaradhi/services/api_service.dart';

/// Checks against the UGC upload frontend handover (2026-09-28).
void main() {
  group('Media validation failed shows per-file reasons (§8)', () {
    DioException rejected(Map<String, dynamic> details) => DioException(
          requestOptions: RequestOptions(path: '/api/v1/ugc/upload-media/'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/ugc/upload-media/'),
            statusCode: 400,
            data: {
              'data': null,
              'meta': {},
              'errors': {
                'code': 400,
                'message': 'Media validation failed.',
                'details': details,
              },
            },
          ),
          type: DioExceptionType.badResponse,
        );

    test('a list of per-file objects is listed under the headline', () {
      final e = UgcApiError.from(rejected({
        'errors': [
          {'file': 'a.jpg', 'error': 'File too large.'},
          {'index': 1, 'message': 'Invalid file signature.'},
        ],
      }));
      expect(e.message, startsWith('Media validation failed.'));
      expect(e.message, contains('a.jpg: File too large.'));
      expect(e.message, contains('#2: Invalid file signature.'));
    });

    test('a file → reason map is listed too', () {
      final reasons = UgcApiError.fileReasons({
        'errors': {
          'b.png': ['Invalid MIME type.']
        }
      });
      expect(reasons, ['b.png: Invalid MIME type.']);
    });

    test('no details keeps the plain message', () {
      expect(UgcApiError.from(rejected({})).message,
          'Media validation failed.');
    });
  });

  group('My Submissions uses the cursor from meta.next (§7)', () {
    test('a bare cursor is used as is', () {
      expect(ApiService.cursorFrom('cD0yMDI2'), 'cD0yMDI2');
    });

    test('a full next URL yields its cursor parameter', () {
      expect(
          ApiService.cursorFrom(
              'https://api.vaaradhinews.com/api/v1/ugc/reporter/submissions/?cursor=abc&page_size=20'),
          'abc');
    });

    test('no next page is null', () {
      expect(ApiService.cursorFrom(null), isNull);
      expect(ApiService.cursorFrom(''), isNull);
    });

    test('page numbers are never sent', () {
      final src = File('lib/services/api_service.dart').readAsStringSync();
      final start = src.indexOf('getReporterSubmissionsPage({');
      final body = src.substring(
          start, src.indexOf('/// First page of My Submissions', start));
      expect(body, isNot(contains("'page'")));
      expect(body, contains("query['cursor']"));
    });
  });

  group('submit is never blindly re-posted after a timeout (§8)', () {
    final src = File('lib/controllers/ugc_controller.dart').readAsStringSync();

    test('a network failure marks the outcome unknown', () {
      expect(src, contains('_unconfirmedSubmitAt = attemptAt'));
    });

    test('the next attempt checks My Submissions before POSTing', () {
      final check = src.indexOf('findRecentSubmission(');
      final post = src.indexOf('_ugcRepository.submitPost(');
      expect(check, greaterThan(0));
      expect(check, lessThan(post));
    });
  });
}
