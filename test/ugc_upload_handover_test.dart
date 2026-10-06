import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/controllers/ugc_controller.dart';
import 'package:vaaradhi/core/errors/ugc_error.dart';
import 'package:vaaradhi/models/category.dart';
import 'package:vaaradhi/models/location_model.dart';
import 'package:vaaradhi/models/ugc_draft.dart';
import 'package:vaaradhi/repositories/ugc_draft_repository.dart';
import 'package:vaaradhi/repositories/ugc_repository.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/ugc_location_sheet.dart';

DioException _backend(int status, String message) {
  final options = RequestOptions(path: '/api/v1/ugc/upload-media/');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {
        'data': null,
        'meta': {},
        'errors': {'code': status, 'message': message},
      },
    ),
  );
}

class _Repo extends UgcRepository {
  Map<String, dynamic>? lastPayload;
  List<String>? lastBatch;
  Object? uploadError;
  Object? submitError;
  int submitCalls = 0;
  int uploadCalls = 0;

  @override
  Future<Map<String, dynamic>> submitPost(Map<String, dynamic> data) async {
    submitCalls++;
    lastPayload = data;
    if (submitError != null) throw submitError!;
    return {'id': 'sub-$submitCalls'};
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
    if (uploadError != null) throw uploadError!;
    return {'status': 'ok'};
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
    lastBatch = List.of(filePaths);
    if (uploadError != null) throw uploadError!;
    return {'status': 'ok'};
  }
}

Category _cat(String slug, String name, int order, {bool active = true}) =>
    Category(
        id: slug,
        name: name,
        slug: slug,
        icon: '',
        order: order,
        isActive: active);

final _liveCategories = [
  _cat('politics', 'రాజకీయాలు', 2),
  _cat('local', 'స్థానికం', 1),
  _cat('old', 'Old', 0, active: false),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('ugc_handover_');
    final s = AppState.instance;
    s.latitude = 17.1415;
    s.longitude = 79.6236;
    s.hasValidLocation = true;
    s.village = '';
    s.subdistrict = 'Nalgonda';
    s.district = 'Nalgonda';
    s.stateName = 'Telangana';
    s.ugcMobileVerified = true;
    s.ugcVerifiedMobile = '9876543210';
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    return ctx;
  }

  Future<UgcController> ready(WidgetTester tester, _Repo repo,
      {int images = 1}) async {
    final paths = [
      for (var i = 0; i < images; i++)
        (File('${tempDir.path}/pic$i.jpg')..writeAsBytesSync([1, 2, 3])).path,
    ];
    await UgcDraftRepository.instance.saveDraft(UgcDraft(
      title: 'Road issue near market',
      description: 'Road damaged near local market area.',
      category: 'Local', // saved by an older build
      type: 'IMAGE',
      filePaths: paths,
    ));
    final c = UgcController(
        ugcRepository: repo, categoriesLoader: () async => _liveCategories);
    await tester.runAsync(() async {
      await c.loadCategories();
      await c.checkForPendingDraft();
      await c.restorePendingDraft();
    });
    return c;
  }

  testWidgets('categories come from the API and the slug is submitted',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo();
    final c = await ready(tester, repo);
    expect(c.categories.map((x) => x.slug), ['local', 'politics']);
    expect(c.category, 'local', reason: 'old "Local" draft maps to its slug');

    c.setCategory('politics');
    await tester.runAsync(() => c.submitNews(context));
    expect(repo.lastPayload!['category'], 'politics');
    expect(repo.lastPayload!['content_type'], 'IMAGE');
    expect(repo.lastPayload!['location_lat'], '17.141500');
  });

  testWidgets('a corrected place is sent; the app location is untouched',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo();
    final c = await ready(tester, repo);
    c.setLocation(
        village: 'Chityal',
        subdistrict: 'Chityal',
        district: 'Nalgonda',
        stateName: 'Telangana');
    expect(c.locationLabel, 'Chityal, Nalgonda, Telangana');

    await tester.runAsync(() => c.submitNews(context));
    expect(repo.lastPayload!['village'], 'Chityal');
    expect(repo.lastPayload!['subdistrict'], 'Chityal');
    expect(repo.lastPayload!['location_lon'], '79.623600');
    expect(AppState.instance.village, '');
    expect(AppState.instance.subdistrict, 'Nalgonda');
  });

  testWidgets('an ordinary draft is not kept: the screen opens clean',
      (tester) async {
    final c = await ready(tester, _Repo());
    c.setTitle('half written');
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    final again = UgcController(ugcRepository: _Repo());
    late bool resumed;
    await tester.runAsync(() async {
      resumed = await again.resumeUnfinishedUpload();
    });
    expect(resumed, isFalse);
    expect(again.title, isEmpty);
  });

  testWidgets(
      'an unfinished upload survives a restart and is not resubmitted',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo()..uploadError = _backend(413, 'Request too large');
    final c = await ready(tester, repo);
    c.setLocation(
        village: 'Chityal',
        subdistrict: 'Chityal',
        district: 'Nalgonda',
        stateName: 'Telangana');
    await tester.runAsync(() => c.submitNews(context));
    expect(c.submissionId, 'sub-1');
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));

    // App restarted: a fresh controller on the post screen.
    final again = UgcController(ugcRepository: repo);
    late bool resumed;
    await tester.runAsync(() async {
      resumed = await again.resumeUnfinishedUpload();
    });
    expect(resumed, isTrue);
    expect(again.submissionId, 'sub-1');
    expect(again.village, 'Chityal');

    repo.uploadError = null;
    await tester.runAsync(() => again.submitNews(context));
    expect(repo.submitCalls, 1, reason: 'continued, not created again');
    expect(again.status, UgcUploadStatus.completed);
  });

  testWidgets('photos upload in the order the reporter arranged',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo();
    final c = await ready(tester, repo, images: 3);
    final original = c.selectedImagePaths;
    c.moveImage(2, 0);
    await tester.runAsync(() => c.submitNews(context));
    expect(repo.lastBatch, [original[2], original[0], original[1]]);
  });

  testWidgets('"Submission not found." never recreates silently',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo()..uploadError = _backend(404, 'Submission not found.');
    final c = await ready(tester, repo);

    await tester.runAsync(() => c.submitNews(context));
    expect(c.errorKind, UgcErrorKind.submissionNotFound);
    expect(c.submissionId, 'sub-1', reason: 'kept, not dropped');
    expect(repo.submitCalls, 1);

    // Only the reporter's explicit choice starts a new submission.
    repo.uploadError = null;
    c.startNewSubmission();
    await tester.runAsync(() => c.submitNews(context));
    expect(repo.submitCalls, 2);
    expect(c.status, UgcUploadStatus.completed);
  });

  testWidgets('daily limit during upload keeps the submission id',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo()..uploadError = _backend(400, 'Daily upload limit reached.');
    final c = await ready(tester, repo);
    await tester.runAsync(() => c.submitNews(context));
    expect(c.errorKind, UgcErrorKind.dailyLimitReached);
    expect(c.submissionId, 'sub-1');
    await tester.runAsync(() => AppState.instance.clearUgcUploadRestrictions());
  });

  test('Telugu letters → te; otherwise the reporter\'s own language', () {
    expect(UgcController.submissionLanguage('రోడ్డు సమస్య', 'details'), 'te');
    // English letters no longer force `en` (that hid approved posts from
    // Telugu readers, whose feeds ask for lang=te).
    expect(
        UgcController.submissionLanguage('Road issue', 'x', fallback: 'te'),
        'te');
    expect(
        UgcController.submissionLanguage('Road issue', 'x', fallback: 'en'),
        'en');
  });

  testWidgets('the reporter\'s pick is what the payload sends',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo();
    final c = await ready(tester, repo);
    c.setLanguage('en');
    await tester.runAsync(() => c.submitNews(context));
    expect(repo.lastPayload!['language'], 'en');
  });

  testWidgets('without a pick a Telugu reader\'s English-letter post is te',
      (tester) async {
    await AppState.instance.setContentLanguage('te');
    final context = await pumpContext(tester);
    final repo = _Repo();
    final c = await ready(tester, repo);
    await tester.runAsync(() => c.submitNews(context));
    expect(repo.lastPayload!['language'], 'te');
    await AppState.instance.setContentLanguage(null);
  });

  test('413 and 429 are told apart', () {
    expect(UgcApiError.from(_backend(413, 'Request too large')).kind,
        UgcErrorKind.payloadTooLarge);
    expect(UgcApiError.from(_backend(429, 'Throttled')).kind,
        UgcErrorKind.rateLimited);
  });

  DioException fieldError(Map<String, dynamic> details,
          {String message = 'An error occurred.'}) =>
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/ugc/submit/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/ugc/submit/'),
          statusCode: 400,
          data: {
            'data': null,
            'meta': {},
            'errors': {'code': 400, 'message': message, 'details': details},
          },
        ),
      );

  test('field errors in errors.details replace "An error occurred."', () {
    final e = UgcApiError.from(fieldError({
      'content_type': ['"image" is not a valid choice.'],
    }));
    expect(e.message, 'Content type: "image" is not a valid choice.');
    expect(e.kind, UgcErrorKind.unknown);
  });

  test('exact backend content_type response shows details, not generic message',
      () {
    final e = UgcApiError.from(fieldError({
      'content_type': ['"image" is not a valid choice.'],
    }));

    expect(e.message, 'Content type: "image" is not a valid choice.');
    expect(e.message, isNot('An error occurred.'));
    expect(e.kind, UgcErrorKind.unknown);
  });

  test('a real headline is kept above the field lines', () {
    final e = UgcApiError.from(fieldError(
        {'location_lat': ['Ensure that there are no more than 9 digits.']},
        message: 'Invalid submission.'));
    expect(e.message,
        'Invalid submission.\nLocation lat: Ensure that there are no more than 9 digits.');
  });

  testWidgets('a field error is shown and keeps the phone verified',
      (tester) async {
    final context = await pumpContext(tester);
    final repo = _Repo()
      ..submitError = fieldError({
        'category': ['Object with slug=x does not exist.'],
      });
    final c = await ready(tester, repo);
    await tester.runAsync(() => c.submitNews(context));
    expect(c.status, UgcUploadStatus.failed);
    expect(c.errorMessage, 'Category: Object with slug=x does not exist.');
    expect(AppState.instance.uploadVerified, isTrue);
    expect(AppState.instance.ugcVerifiedMobile, '9876543210');
  });

  testWidgets('coordinates go out with 6 decimals', (tester) async {
    AppState.instance.latitude = 17.438567890123456;
    AppState.instance.longitude = 78.41234567891234;
    final context = await pumpContext(tester);
    final repo = _Repo();
    final c = await ready(tester, repo);
    await tester.runAsync(() => c.submitNews(context));
    expect(repo.lastPayload!['location_lat'], '17.438568');
    expect(repo.lastPayload!['location_lon'], '78.412346');
    expect(repo.lastPayload!['mobile'], '9876543210');
  });


  group('location sheet', () {
    Future<UgcPlace?> openSheet(WidgetTester tester,
        Future<void> Function() act) async {
      UgcPlace? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await UgcLocationSheet.open(
                  ctx,
                  const UgcPlace(district: 'Nalgonda', stateName: 'Telangana'),
                  search: (q) async => [
                    const LocationSearchResult(
                      type: LocationLevel.village,
                      id: 'v1',
                      nameEn: 'Chityal',
                      nameTe: 'చిట్యాల',
                      subdistrict: 'Chityal',
                      district: 'Nalgonda',
                      state: 'Telangana',
                    ),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('search fills every level and returns it', (tester) async {
      final place = await openSheet(tester, () async {
        await tester.enterText(
            find.byKey(const Key('ugc_location_search')), 'chit');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ugc_location_result_0')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('ugc_location_save')));
        await tester.tap(find.byKey(const Key('ugc_location_save')));
      });
      expect(place!.village, 'Chityal');
      expect(place.subdistrict, 'Chityal');
      expect(place.district, 'Nalgonda');
      expect(place.stateName, 'Telangana');
    });

    testWidgets('typed by hand', (tester) async {
      final place = await openSheet(tester, () async {
        await tester.enterText(
            find.byKey(const Key('ugc_location_village')), 'Ramannapet');
        await tester.ensureVisible(find.byKey(const Key('ugc_location_save')));
        await tester.tap(find.byKey(const Key('ugc_location_save')));
      });
      expect(place!.village, 'Ramannapet');
      expect(place.district, 'Nalgonda');
    });

    testWidgets('"use GPS" goes back to the detected place', (tester) async {
      final place = await openSheet(tester, () async {
        await tester.tap(find.byKey(const Key('ugc_location_use_gps')));
      });
      expect(place!.useGps, isTrue);
    });
  });
}
