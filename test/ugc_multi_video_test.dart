import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/controllers/ugc_controller.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/core/utils/media_picker_helper.dart';
import 'package:vaaradhi/core/utils/media_validator.dart';
import 'package:vaaradhi/models/reporter_post.dart';
import 'package:vaaradhi/models/ugc_draft.dart';
import 'package:vaaradhi/repositories/ugc_draft_repository.dart';
import 'package:vaaradhi/services/api_service.dart';

class _Picker extends MediaPickerHelper {
  List<String> paths = [];
  int? requestedLimit;

  @override
  Future<List<XFile>> pickVideosFromGallery({int maxItems = 10}) async {
    requestedLimit = maxItems;
    return paths.take(maxItems).map(XFile.new).toList();
  }

  @override
  Future<XFile?> recordVideoFromCamera(
          {Duration maxDuration = const Duration(minutes: 3)}) async =>
      paths.isEmpty ? null : XFile(paths.first);
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    final bytes = <int>[];
    if (body != null) {
      await for (final chunk in body) {
        bytes.addAll(chunk);
      }
    }
    bodies.add(utf8.decode(bytes));
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'media_items': [
            {'media_type': 'VIDEO', 'url': 'https://example.com/one.mp4'},
            {'media_type': 'VIDEO', 'url': 'https://example.com/two.mp4'},
          ]
        }
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late List<String> videos;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('ugc_multi_video_');
    videos = List.generate(
        11,
        (i) =>
            (File('${dir.path}/clip$i.mp4')..writeAsBytesSync([1, 2, 3])).path);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('selection appends, deduplicates, reorders, removes and caps videos',
      () async {
    final picker = _Picker()..paths = videos.take(2).toList();
    final controller = UgcController(pickerHelper: picker)
      ..setType(PostType.video);
    addTearDown(controller.dispose);
    await controller.pickVideoFromGallery();
    expect(controller.selectedVideoPaths, videos.take(2));
    picker.paths = [videos[1], videos[2]];
    await controller.pickVideoFromGallery();
    expect(controller.selectedVideoPaths, videos.take(3));
    controller.moveVideo(2, 0);
    expect(controller.selectedVideoPath, videos[2]);
    controller.removeVideoAt(1);
    expect(controller.selectedVideoPaths, [videos[2], videos[1]]);
    picker.paths = videos.skip(3).toList();
    await controller.pickVideoFromGallery();
    expect(picker.requestedLimit, 8);
    expect(controller.selectedVideoPaths.length, 10);
    await controller.recordVideoFromCamera();
    expect(controller.selectedVideoPaths.length, 10);
    expect(controller.errorMessage, contains('Maximum 10'));
    controller.setType(PostType.image);
    expect(controller.selectedVideoPaths, isEmpty);
  });

  test('batch validation rejects later invalid files and over-limit batches',
      () async {
    final image = File('${dir.path}/photo.jpg')..writeAsBytesSync([1]);
    final invalid =
        await MediaValidator.validateVideosBatch([videos.first, image.path]);
    expect(invalid.isValid, isFalse);
    expect(invalid.errorMessage, contains('Video 2'));
    expect((await MediaValidator.validateVideosBatch(videos)).isValid, isFalse);
    expect((await MediaValidator.validateVideosBatch([])).isValid, isFalse);
  });

  test('unfinished video drafts restore and save every existing path',
      () async {
    final repository = UgcDraftRepository.instance;
    await repository.saveDraft(UgcDraft(
      title: 'News',
      description: 'Details',
      category: 'local',
      type: 'VIDEO',
      submissionId: 'existing',
      filePaths: [videos[0], '${dir.path}/missing.mp4', videos[1]],
    ));
    final controller = UgcController();
    addTearDown(controller.dispose);
    await controller.checkForPendingDraft();
    await controller.restorePendingDraft();
    expect(controller.selectedVideoPaths, videos.take(2));
    controller.moveVideo(1, 0);
    // Flush the asynchronous draft save triggered by the reorder.
    await Future<void>.delayed(Duration.zero);
    expect((await repository.loadDraft())!.filePaths, [videos[1], videos[0]]);
  });

  test('batch sends repeated files fields and preserves every response item',
      () async {
    final dio = ApiClient.instance.dio;
    final previous = dio.httpClientAdapter;
    final adapter = _Adapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);
    final response = await ApiService.instance.uploadMediaBatch(
      submissionId: 'submission',
      mobile: '9876543210',
      filePaths: videos.take(2).toList(),
      mediaTypes: ['VIDEO', 'VIDEO'],
    );
    final form = adapter.requests.single.data as FormData;
    expect(form.files.map((entry) => entry.key), ['files', 'files']);
    expect(form.files.map((entry) => entry.value.filename),
        ['clip0.mp4', 'clip1.mp4']);
    expect(RegExp('name="files"').allMatches(adapter.bodies.single).length, 2);
    expect(response['media_items'], hasLength(2));
  });
}
