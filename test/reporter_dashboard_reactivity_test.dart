import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/reporter_post.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Backend contract (GET /ugc/reporter/dashboard/): the dashboard counts are
/// the server's — refreshed after every upload, never calculated locally.
/// The post list still reacts at once; only the numbers wait for the server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = AppState.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state
      // Logged out here so refreshReporterDashboard() makes no network call:
      // the counts below are exactly what the "server" last sent.
      ..isLoggedIn = false
      ..isReporter = true
      ..reporterTokens = 0
      ..reporterPosts.clear()
      ..reporterPendingCount = 2
      ..reporterApprovedCount = 1
      ..reporterPublishedCount = 1
      ..reporterRejectedCount = 0
      ..reporterTotalSubmissions = 3;
  });

  group('Reporter dashboard: list reacts, counts stay the server\'s', () {
    test('a new upload is listed as pending; counts are not guessed', () {
      final post = state.submitReporterPost(
        id: 'post-1',
        type: PostType.image,
        caption: 'First News Story',
        category: 'local',
        mediaUrl: 'https://example.com/pic1.jpg',
      );
      expect(post.status, PostStatus.pending);
      expect(state.reporterPosts.first.id, 'post-1');
      // Unchanged until the dashboard is re-read.
      expect(state.pendingCount, 2);
      expect(state.totalSubmissionsCount, 3);
    });

    test('the same upload twice is listed once', () {
      for (var i = 0; i < 2; i++) {
        state.submitReporterPost(
            id: 'dup',
            type: PostType.image,
            caption: 'x',
            category: 'local',
            mediaUrl: '');
      }
      expect(state.reporterPosts.where((p) => p.id == 'dup'), hasLength(1));
    });

    test('a status change updates the post and its reason, not the counts',
        () {
      state.submitReporterPost(
          id: 'post-200',
          type: PostType.image,
          caption: 'Story',
          category: 'local',
          mediaUrl: '');
      state.onPostStatusChanged(
          'post-200', PostStatus.rejected, 'Inappropriate image');
      final post = state.reporterPosts.firstWhere((p) => p.id == 'post-200');
      expect(post.status, PostStatus.rejected);
      expect(post.rejectionReason, 'Inappropriate image');
      expect(state.rejectedCount, 0);
      expect(state.pendingCount, 2);
    });

    test('bulk action updates every listed post', () {
      for (final id in ['bulk-1', 'bulk-2']) {
        state.submitReporterPost(
            id: id,
            type: PostType.image,
            caption: id,
            category: 'local',
            mediaUrl: '');
      }
      state.onPostsBulkAction(['bulk-1', 'bulk-2'], PostStatus.approved);
      expect(
          state.reporterPosts
              .where((p) => p.id.startsWith('bulk-'))
              .every((p) => p.status == PostStatus.approved),
          isTrue);
      expect(state.approvedCount, 1);
    });

    test('admin approve still credits a token', () {
      state.submitReporterPost(
          id: 'adm-1',
          type: PostType.image,
          caption: 'Admin test post',
          category: 'local',
          mediaUrl: '');
      state.adminApprovePost('adm-1');
      expect(state.reporterPosts.first.status, PostStatus.approved);
      expect(state.reporterTokens, 1);
    });

    test('before the dashboard loads every count is 0, not a local guess',
        () {
      state
        ..reporterPendingCount = null
        ..reporterApprovedCount = null
        ..reporterPublishedCount = null
        ..reporterRejectedCount = null
        ..reporterTotalSubmissions = null;
      state.submitReporterPost(
          id: 'p',
          type: PostType.image,
          caption: 'x',
          category: 'local',
          mediaUrl: '');
      expect(state.pendingCount, 0);
      expect(state.totalSubmissionsCount, 0);
    });
  });
}
