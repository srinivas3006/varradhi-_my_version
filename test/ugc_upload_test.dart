import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/controllers/ugc_controller.dart';
import 'package:vaaradhi/core/utils/media_validator.dart';
import 'package:vaaradhi/models/reporter_post.dart';
import 'package:vaaradhi/models/ugc_draft.dart';
import 'package:vaaradhi/repositories/ugc_draft_repository.dart';
import 'package:vaaradhi/repositories/ugc_repository.dart';
import 'package:vaaradhi/state/app_state.dart';

// Fake UgcRepository for deterministic unit testing
class FakeUgcRepository extends UgcRepository {
  bool submitShouldFail = false;
  bool uploadShouldFail = false;
  int submitCalls = 0;
  int uploadCalls = 0;
  String? lastSubmissionId;

  @override
  Future<Map<String, dynamic>> submitPost(Map<String, dynamic> data) async {
    submitCalls++;
    if (submitShouldFail) {
      throw Exception('Server rejected submission');
    }
    return {
      'id': 'sub-uuid-12345',
      'submission_id': 'sub-uuid-12345',
      'upload_status': 'PENDING',
    };
  }

  @override
  Future<Map<String, dynamic>> uploadMedia({
    required String submissionId,
    required String mobile,
    required String mediaType,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    uploadCalls++;
    lastSubmissionId = submissionId;
    if (uploadShouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/upload'),
        response: Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: 500,
        ),
      );
    }
    onSendProgress?.call(50, 100);
    onSendProgress?.call(100, 100);
    return {'status': 'SUCCESS'};
  }

  @override
  Future<Map<String, dynamic>> uploadMediaBatch({
    required String submissionId,
    required String mobile,
    required List<String> filePaths,
    required List<String> mediaTypes,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    uploadCalls++;
    lastSubmissionId = submissionId;
    if (uploadShouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/upload'),
        response: Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: 500,
        ),
      );
    }
    onSendProgress?.call(50, 100);
    onSendProgress?.call(100, 100);
    return {'status': 'SUCCESS'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ugc_test_');
    AppState.instance.latitude = 17.385044;
    AppState.instance.longitude = 78.486671;
    AppState.instance.hasValidLocation = true;
    AppState.instance.district = 'Hyderabad';
    AppState.instance.stateName = 'Telangana';
    AppState.instance.userPhone = '9876543210';
    // Uploads now require a backend-verified UGC mobile.
    AppState.instance.ugcMobileVerified = true;
    AppState.instance.ugcVerifiedMobile = '9876543210';
    AppState.instance.ugcUploadLockedUntil = null;
    AppState.instance.ugcBlockedAt = null;
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // submitNews needs a BuildContext to show the location-permission sheet
  // when location is missing; tests that already have a valid location
  // never touch it, but the signature still requires one.
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        captured = context;
        return const SizedBox();
      }),
    ));
    return captured;
  }

  group('MediaValidator Tests', () {
    test('Valid JPEG image within 5MB passes', () async {
      final file = File('${tempDir.path}/photo.jpg');
      file.writeAsBytesSync(List.filled(1024 * 50, 1)); // 50 KB

      final result = await MediaValidator.validateImage(file.path);
      expect(result.isValid, isTrue);
      expect(result.extension, equals('jpg'));
      expect(result.fileSizeBytes, equals(1024 * 50));
    });

    test('Valid PNG image passes', () async {
      final file = File('${tempDir.path}/graphic.png');
      file.writeAsBytesSync(List.filled(1024 * 100, 1)); // 100 KB

      final result = await MediaValidator.validateImage(file.path);
      expect(result.isValid, isTrue);
      expect(result.extension, equals('png'));
    });

    test('Valid MP4 video within 50MB passes', () async {
      final file = File('${tempDir.path}/news_clip.mp4');
      file.writeAsBytesSync(List.filled(1024 * 500, 1)); // 500 KB

      final result = await MediaValidator.validateVideo(file.path);
      expect(result.isValid, isTrue);
      expect(result.extension, equals('mp4'));
    });

    test('Missing file returns invalid', () async {
      final result = await MediaValidator.validateImage('${tempDir.path}/non_existent.jpg');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('does not exist'));
    });

    test('Empty file (0 bytes) returns invalid', () async {
      final file = File('${tempDir.path}/empty.jpg');
      file.writeAsBytesSync([]);

      final result = await MediaValidator.validateImage(file.path);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('empty'));
    });

    test('Unsupported file format returns invalid', () async {
      final file = File('${tempDir.path}/document.pdf');
      file.writeAsBytesSync([1, 2, 3]);

      final result = await MediaValidator.validateImage(file.path);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Unsupported Image format'));
    });

    test('Missing file extension returns invalid', () async {
      final file = File('${tempDir.path}/no_extension');
      file.writeAsBytesSync([1, 2, 3]);

      final result = await MediaValidator.validateImage(file.path);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('missing file extension'));
    });

    test('Oversized image (>5MB, backend limit) returns invalid', () async {
      final file = File('${tempDir.path}/huge.jpg');
      // 6 MB: passed the old 10 MB check, then failed on upload.
      file.writeAsBytesSync(List.filled(6 * 1024 * 1024, 1));

      final result = await MediaValidator.validateImage(file.path);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('too large'));
      expect(result.errorMessage, contains('5 MB'));
    });

    test('video formats match the backend: webm yes, mkv no', () async {
      final webm = File('${tempDir.path}/clip.webm')
        ..writeAsBytesSync(List.filled(1024, 1));
      final mkv = File('${tempDir.path}/clip.mkv')
        ..writeAsBytesSync(List.filled(1024, 1));
      expect((await MediaValidator.validateVideo(webm.path)).isValid, isTrue);
      expect((await MediaValidator.validateVideo(mkv.path)).isValid, isFalse);
    });

    test('Images batch validation handles multiple files and caps at 10', () async {
      final paths = <String>[];
      for (int i = 0; i < 5; i++) {
        final f = File('${tempDir.path}/img_$i.jpg');
        f.writeAsBytesSync([1, 2, 3]);
        paths.add(f.path);
      }

      final validBatch = await MediaValidator.validateImagesBatch(paths);
      expect(validBatch.isValid, isTrue);

      final overPaths = List.generate(11, (i) => paths.first);
      final invalidBatch = await MediaValidator.validateImagesBatch(overPaths);
      expect(invalidBatch.isValid, isFalse);
      expect(invalidBatch.errorMessage, contains('Maximum 10 photos'));
    });
  });

  group('UgcDraft Model & Repository Tests', () {
    test('UgcDraft serializes and deserializes cleanly', () {
      final draft = UgcDraft(
        title: 'Road Repair',
        description: 'New asphalt laid',
        category: 'Local',
        type: 'IMAGE',
        filePaths: ['/path/to/1.jpg', '/path/to/2.jpg'],
        submissionId: 'sub-999',
        uploadStatus: UgcUploadStatus.failed,
        locationLat: '17.3850',
        locationLon: '78.4867',
        district: 'Hyderabad',
        stateName: 'Telangana',
        mobile: '9876543210',
      );

      final json = draft.toJson();
      final restored = UgcDraft.fromJson(json);

      expect(restored.title, equals('Road Repair'));
      expect(restored.description, equals('New asphalt laid'));
      expect(restored.filePaths.length, equals(2));
      expect(restored.submissionId, equals('sub-999'));
      expect(restored.uploadStatus, equals(UgcUploadStatus.failed));
    });

    test('findMissingFiles identifies deleted local media', () async {
      final existingFile = File('${tempDir.path}/exists.jpg')..writeAsBytesSync([1]);
      final missingPath = '${tempDir.path}/deleted.jpg';

      final draft = UgcDraft(
        title: 'Test',
        description: 'Test desc',
        category: 'Local',
        type: 'IMAGE',
        filePaths: [existingFile.path, missingPath],
      );

      final missing = await draft.findMissingFiles();
      expect(missing, contains(missingPath));
      expect(missing, isNot(contains(existingFile.path)));
    });

    test('UgcDraftRepository saves, loads, and clears drafts', () async {
      final repo = UgcDraftRepository();
      final draft = UgcDraft(
        title: 'Draft Title',
        description: 'Draft Description',
        category: 'Politics',
        type: 'VIDEO',
        filePaths: ['/video.mp4'],
      );

      await repo.saveDraft(draft);
      expect(await repo.hasDraft(), isTrue);

      final loaded = await repo.loadDraft();
      expect(loaded, isNotNull);
      expect(loaded!.title, equals('Draft Title'));
      expect(loaded.category, equals('Politics'));

      await repo.clearDraft();
      expect(await repo.hasDraft(), isFalse);
      expect(await repo.loadDraft(), isNull);
    });
  });

  group('UgcController Lifecycle & State Machine Tests', () {
    testWidgets('Validation fails if title or description is missing',
        (tester) async {
      final context = await pumpContext(tester);
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);

      // Empty title
      final success1 = await controller.submitNews(context);
      expect(success1, isFalse);
      expect(controller.errorMessage, contains('శీర్షికను'));

      // Empty description
      controller.setTitle('Test News');
      final success2 = await controller.submitNews(context);
      expect(success2, isFalse);
      expect(controller.errorMessage, contains('వివరాలను'));
    });

    testWidgets('Validation fails if no media is attached', (tester) async {
      final context = await pumpContext(tester);
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);
      controller.setTitle('Test News');
      controller.setDescription('Detailed report on the ground');

      // PostType is image by default, no images attached
      final success = await controller.submitNews(context);
      expect(success, isFalse);
      expect(controller.errorMessage, contains('ఫోటోను జతపరచండి'));
    });

    testWidgets(
        'Validation fails if location is missing and reader dismisses the prompt',
        (tester) async {
      AppState.instance.latitude = null;
      AppState.instance.longitude = null;

      final context = await pumpContext(tester);
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);

      // Restore title/description/media from a draft rather than calling
      // setTitle/setDescription directly: those each fire an unawaited
      // autosave (UgcController._autoSaveDraft), and two of them back to
      // back here would race the explicit saveDraft below and could
      // clobber it depending on scheduling.
      final img = File('${tempDir.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      final draft = UgcDraft(
        title: 'News Without GPS',
        description: 'Details',
        category: 'Local',
        type: 'IMAGE',
        filePaths: [img.path],
      );
      await UgcDraftRepository.instance.saveDraft(draft);

      // Both draft restore (findMissingFiles) and submitNews (MediaValidator)
      // do real dart:io File I/O, which never resolves under flutter_test's
      // default FakeAsync zone without tester.runAsync. submitNews also
      // needs to show/await the location sheet, so the interaction runs
      // inside the same runAsync call — but a single pumpAndSettle right
      // after firing submitNews can race ahead of that real I/O and find
      // nothing scheduled yet, so poll with real delays until the sheet
      // actually appears rather than assuming one pump cycle is enough.
      late bool success;
      await tester.runAsync(() async {
        await controller.checkForPendingDraft();
        await controller.restorePendingDraft();

        final future = controller.submitNews(context);

        for (var i = 0;
            i < 50 && find.text('Maybe later').evaluate().isEmpty;
            i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
        expect(find.text('Maybe later'), findsOneWidget);

        // The text exists from the sheet's first frame, while it is still
        // below the screen; let the slide-up finish so the tap lands.
        await tester.pumpAndSettle();
        await tester.tap(find.text('Maybe later'));
        await tester.pumpAndSettle();

        success = await future;
      });

      expect(success, isFalse);
      expect(controller.errorMessage, contains('GPS'));
    });

    testWidgets('Full submission and upload pipeline progresses to completed',
        (tester) async {
      final context = await pumpContext(tester);
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);

      final img = File('${tempDir.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      final draft = UgcDraft(
        title: 'Breaking News',
        description: 'Happened today near the town center',
        category: 'Local',
        type: 'IMAGE',
        filePaths: [img.path],
      );
      await UgcDraftRepository.instance.saveDraft(draft);

      // Real dart:io File I/O (draft restore + MediaValidator inside
      // submitNews) never resolves under the default FakeAsync test zone;
      // runAsync escapes to the real zone for it. No sheet interaction is
      // needed here (setUp already gives a valid location), so the whole
      // sequence can run inside one call.
      late bool success;
      await tester.runAsync(() async {
        await controller.checkForPendingDraft();
        await controller.restorePendingDraft();
        success = await controller.submitNews(context);
      });

      expect(success, isTrue);
      expect(controller.status, equals(UgcUploadStatus.completed));
      expect(controller.uploadProgress, equals(1.0));
      expect(fakeRepo.submitCalls, equals(1));
      expect(fakeRepo.uploadCalls, equals(1));
      expect(fakeRepo.lastSubmissionId, equals('sub-uuid-12345'));

      // Completed upload clears draft from repository
      expect(await UgcDraftRepository.instance.hasDraft(), isFalse);
    });

    testWidgets(
        'Failed media upload preserves submissionId and draft for retry',
        (tester) async {
      final context = await pumpContext(tester);
      final fakeRepo = FakeUgcRepository()..uploadShouldFail = true;
      final controller = UgcController(ugcRepository: fakeRepo);

      final img = File('${tempDir.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      final draft = UgcDraft(
        title: 'Pending Report',
        description: 'Report details',
        category: 'Local',
        type: 'IMAGE',
        filePaths: [img.path],
      );
      await UgcDraftRepository.instance.saveDraft(draft);

      late bool success;
      late UgcUploadStatus statusAfterFailure;
      late String? submissionIdAfterFailure;
      late bool retrySuccess;
      await tester.runAsync(() async {
        await controller.checkForPendingDraft();
        await controller.restorePendingDraft();

        success = await controller.submitNews(context);
        statusAfterFailure = controller.status;
        submissionIdAfterFailure = controller.submissionId;

        // The submission ID is preserved!
        // Now retry with working upload
        fakeRepo.uploadShouldFail = false;
        retrySuccess = await controller.submitNews(context);
      });

      expect(success, isFalse);
      expect(statusAfterFailure, equals(UgcUploadStatus.failed));
      expect(submissionIdAfterFailure, equals('sub-uuid-12345'));
      expect(retrySuccess, isTrue);
      expect(controller.status, equals(UgcUploadStatus.completed));
      // submitPost should NOT have been called again! It reused the existing submissionId!
      expect(fakeRepo.submitCalls, equals(1));
    });

    test('Upload cancellation sets status to cancelled and stops upload', () async {
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);

      controller.cancelUpload();
      expect(controller.status, equals(UgcUploadStatus.cancelled));
      expect(controller.errorMessage, contains('రద్దు చేయబడింది'));
    });

    testWidgets('Duplicate submit call while in-flight is rejected',
        (tester) async {
      final context = await pumpContext(tester);
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);

      final img = File('${tempDir.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      final draft = UgcDraft(
        title: 'Breaking News',
        description: 'Details',
        category: 'Local',
        type: 'IMAGE',
        filePaths: [img.path],
      );
      await UgcDraftRepository.instance.saveDraft(draft);

      late List<bool> results;
      await tester.runAsync(() async {
        await controller.checkForPendingDraft();
        await controller.restorePendingDraft();

        // Fire first submit
        final future1 = controller.submitNews(context);
        // Rapid secondary tap
        final future2 = controller.submitNews(context);

        results = await Future.wait([future1, future2]);
      });

      // One succeeds, second was rejected by duplicate guard
      expect(results, contains(true));
      expect(results, contains(false));
      expect(fakeRepo.submitCalls, equals(1));
    });
  });
}
