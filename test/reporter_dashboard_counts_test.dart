import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/state/app_state.dart';

void main() {
  int? count(Map<String, dynamic> d, String s) =>
      AppState.dashboardCount(d, s);

  group('dashboard counts are read whatever the backend calls them', () {
    test('flat *_count names', () {
      final d = {'total_submissions': 4, 'pending_count': 2, 'rejected_count': 1};
      expect(count(d, 'pending'), 2);
      expect(count(d, 'rejected'), 1);
      expect(count(d, 'total'), 4);
    });

    test('bare names and string numbers', () {
      final d = {'pending': '3', 'published': 5};
      expect(count(d, 'pending'), 3);
      expect(count(d, 'published'), 5);
    });

    test('nested under counts / status_counts / totals', () {
      expect(count({'counts': {'pending': 2}}, 'pending'), 2);
      expect(count({'status_counts': {'approved_count': 7}}, 'approved'), 7);
      expect(count({'totals': {'total': 9}}, 'total'), 9);
    });

    test('a missing count is null, never a made-up 0', () {
      final d = {'trust_score': 80, 'reporter_level': 'VERIFIED_USER'};
      expect(count(d, 'pending'), isNull);
      expect(count(d, 'total'), isNull);
    });
  });


  test('the backend-confirmed dashboard sample is read exactly', () {
    final dash = {
      'total_submissions': 5,
      'pending_count': 3,
      'approved_count': 1,
      'published_count': 1,
      'rejected_count': 1,
      'trust_score': 42,
      'reporter_level': 'TRUSTED_REPORTER',
      'recent_submissions': [],
    };
    expect(AppState.dashboardCount(dash, 'total'), 5);
    expect(AppState.dashboardCount(dash, 'pending'), 3);
    expect(AppState.dashboardCount(dash, 'approved'), 1);
    expect(AppState.dashboardCount(dash, 'published'), 1);
    expect(AppState.dashboardCount(dash, 'rejected'), 1);
  });
}
