import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/controllers/ugc_controller.dart';
import 'package:way2news_clone/core/utils/media_validator.dart';
import 'package:way2news_clone/models/reporter_post.dart';
import 'package:way2news_clone/models/ugc_draft.dart';
import 'package:way2news_clone/repositories/ugc_draft_repository.dart';
import 'package:way2news_clone/repositories/ugc_repository.dart';
import 'package:way2news_clone/state/app_state.dart';

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
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('MediaValidator Tests', () {
    test('Valid JPEG image within 10MB passes', () async {
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

    test('Oversized image (>10MB) returns invalid', () async {
      final file = File('${tempDir.path}/huge.jpg');
      // 11 MB
      file.writeAsBytesSync(List.filled(11 * 1024 * 1024, 1));

      final result = await MediaValidator.validateImage(file.path);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('too large'));
      expect(result.errorMessage, contains('10 MB'));
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
    test('Validation fails if title or description is missing', () async {
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);

      // Empty title
      final success1 = await controller.submitNews();
      expect(success1, isFalse);
      expect(controller.errorMessage, contains('శీర్షికను'));

      // Empty description
      controller.setTitle('Test News');
      final success2 = await controller.submitNews();
      expect(success2, isFalse);
      expect(controller.errorMessage, contains('వివరాలను'));
    });

    test('Validation fails if no media is attached', () async {
      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);
      controller.setTitle('Test News');
      controller.setDescription('Detailed report on the ground');

      // PostType is image by default, no images attached
      final success = await controller.submitNews();
      expect(success, isFalse);
      expect(controller.errorMessage, contains('ఫోటోను జతపరచండి'));
    });

    test('Validation fails if location is missing', () async {
      AppState.instance.latitude = null;
      AppState.instance.longitude = null;

      final fakeRepo = FakeUgcRepository();
      final controller = UgcController(ugcRepository: fakeRepo);
      controller.setTitle('News Without GPS');
      controller.setDescription('Details');

      final img = File('${tempDir.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      controller.setType(PostType.image);
      // Simulate picked photo
      final draft = UgcDraft(
        title: 'News Without GPS',
        description: 'Details',
        category: 'Local',
        type: 'IMAGE',
        filePaths: [img.path],
      );
      await UgcDraftRepository.instance.saveDraft(draft);
      await controller.checkForPendingDraft();
      await controller.restorePendingDraft();

      // Submit attempt when location is unavailable
      final success = await controller.submitNews();
      expect(success, isFalse);
      expect(controller.errorMessage, contains('Location'));
    });

    test('Full submission and upload pipeline progresses to completed', () async {
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
      await controller.checkForPendingDraft();
      await controller.restorePendingDraft();

      final success = await controller.submitNews();
      expect(success, isTrue);
      expect(controller.status, equals(UgcUploadStatus.completed));
      expect(controller.uploadProgress, equals(1.0));
      expect(fakeRepo.submitCalls, equals(1));
      expect(fakeRepo.uploadCalls, equals(1));
      expect(fakeRepo.lastSubmissionId, equals('sub-uuid-12345'));

      // Completed upload clears draft from repository
      expect(await UgcDraftRepository.instance.hasDraft(), isFalse);
    });

    test('Failed media upload preserves submissionId and draft for retry', () async {
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
      await controller.checkForPendingDraft();
      await controller.restorePendingDraft();

      final success = await controller.submitNews();
      expect(success, isFalse);
      expect(controller.status, equals(UgcUploadStatus.failed));
      expect(controller.submissionId, equals('sub-uuid-12345'));

      // The submission ID is preserved!
      // Now retry with working upload
      fakeRepo.uploadShouldFail = false;
      final retrySuccess = await controller.submitNews();
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

    test('Duplicate submit call while in-flight is rejected', () async {
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
      await controller.checkForPendingDraft();
      await controller.restorePendingDraft();

      // Fire first submit
      final future1 = controller.submitNews();
      // Rapid secondary tap
      final future2 = controller.submitNews();

      final results = await Future.wait([future1, future2]);
      // One succeeds, second was rejected by duplicate guard
      expect(results, contains(true));
      expect(results, contains(false));
      expect(fakeRepo.submitCalls, equals(1));
    });
  });
}
