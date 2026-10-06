import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/features/admin/data/models/admin_ugc_submission_model.dart';
import 'package:vaaradhi/features/admin/data/services/admin_media_tools.dart';
import 'package:vaaradhi/features/admin/presentation/widgets/admin_media_viewer.dart';
import 'package:vaaradhi/utils/share_service.dart';

/// Serves every URL as a few bytes, except ones containing "broken".
class _Cdn implements HttpClientAdapter {
  final List<String> seen = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    seen.add(o.uri.toString());
    if (o.uri.toString().contains('broken')) {
      return ResponseBody.fromString('nope', 404);
    }
    return ResponseBody.fromBytes([1, 2, 3, 4], 200);
  }

  @override
  void close({bool force = false}) {}
}

AdminUgcSubmissionModel _submission({List<Map<String, dynamic>>? media}) =>
    AdminUgcSubmissionModel.fromJson({
      'id': 'sub-9',
      'title': 'Road',
      'media_type': 'image',
      'media_url': 'https://cdn.test/one.jpg',
      if (media != null) 'media_items': media,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late _Cdn cdn;
  late List<(String, bool)> saved;
  late AdminMediaTools tools;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('admin_media_');
    cdn = _Cdn();
    saved = [];
    AdminMediaTools.saveToGallery = (path, {bool isVideo = false}) async {
      saved.add((path, isVideo));
      return ShareService.downloadSaved;
    };
    AdminMediaTools.brand = (bytes, name) async {
      final f = File('${tmp.path}/$name.jpg')..writeAsBytesSync(bytes);
      return f;
    };
    tools = AdminMediaTools(
        dio: Dio()..httpClientAdapter = cdn, tempDir: () async => tmp);
  });

  tearDown(() {
    AdminMediaTools.saveToGallery = ShareService.saveFileToGallery;
    AdminMediaTools.brand = ShareService.brandPhotoBytes;
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('media list', () {
    test('every media_items entry, in sort order', () {
      final s = _submission(media: [
        {'media_url': 'https://cdn.test/b.mp4', 'media_type': 'VIDEO', 'sort_order': 1},
        {'media_url': 'https://cdn.test/a.jpg', 'media_type': 'IMAGE', 'sort_order': 0},
      ]);
      expect(s.allMedia.map((m) => m.url),
          ['https://cdn.test/a.jpg', 'https://cdn.test/b.mp4']);
      expect(s.allMedia.last.isVideo, isTrue);
      expect(s.firstImage!.url, 'https://cdn.test/a.jpg');
    });

    test('no list → the single original', () {
      final s = _submission();
      expect(s.allMedia.single.url, 'https://cdn.test/one.jpg');
    });

    test('a video-only submission has nothing to brand in the app', () {
      final s = _submission(media: [
        {'media_url': 'https://cdn.test/v.mp4', 'media_type': 'VIDEO'},
      ]);
      expect(s.firstImage, isNull);
    });
  });

  test('download saves every photo and video, videos as video', () async {
    final s = _submission(media: [
      {'media_url': 'https://cdn.test/a.jpg', 'media_type': 'IMAGE'},
      {'media_url': 'https://cdn.test/b.mp4', 'media_type': 'VIDEO'},
    ]);
    final r = await tools.downloadAll(s);
    expect(r.saved, 2);
    expect(r.failed, 0);
    expect(saved.map((e) => e.$2), [false, true]);
    expect(saved.first.$1, endsWith('.jpg'));
    expect(saved.last.$1, endsWith('.mp4'));
  });

  test('one broken file does not stop the rest', () async {
    final s = _submission(media: [
      {'media_url': 'https://cdn.test/broken.jpg', 'media_type': 'IMAGE'},
      {'media_url': 'https://cdn.test/ok.jpg', 'media_type': 'IMAGE'},
    ]);
    final r = await tools.downloadAll(s);
    expect(r.saved, 1);
    expect(r.failed, 1);
  });

  test('gallery permission refused is reported, not hidden', () async {
    AdminMediaTools.saveToGallery =
        (path, {bool isVideo = false}) async => ShareService.downloadPermissionDenied;
    final r = await tools.downloadAll(_submission());
    expect(r.permissionDenied, isTrue);
    expect(r.saved, 0);
  });

  test('brand uses the first photo', () async {
    final s = _submission(media: [
      {'media_url': 'https://cdn.test/v.mp4', 'media_type': 'VIDEO'},
      {'media_url': 'https://cdn.test/photo.jpg', 'media_type': 'IMAGE'},
    ]);
    final f = await tools.brandFirstPhoto(s);
    expect(f, isNotNull);
    expect(cdn.seen.last, 'https://cdn.test/photo.jpg');
    expect(f!.path, contains('vaaradhi_branded_sub-9'));
  });

  group('viewer buttons', () {
    Future<void> pump(WidgetTester tester, AdminUgcSubmissionModel s,
        {VoidCallback? onDownload, VoidCallback? onBrand}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminMediaViewer(
              submission: s,
              onDownload: onDownload ?? () {},
              onAutoBrand: onBrand ?? () {},
            ),
          ),
        ),
      ));
    }

    testWidgets('photo submission: Download and Add brand both shown',
        (tester) async {
      var downloads = 0, brands = 0;
      await pump(tester, _submission(),
          onDownload: () => downloads++, onBrand: () => brands++);
      await tester.tap(find.byKey(const Key('admin_media_download')));
      await tester.tap(find.byKey(const Key('admin_media_auto_brand')));
      expect(downloads, 1);
      expect(brands, 1);
    });

    testWidgets('video-only: Download yes, in-app brand no', (tester) async {
      await pump(
          tester,
          _submission(media: [
            {'media_url': 'https://cdn.test/v.mp4', 'media_type': 'VIDEO'},
          ]));
      expect(find.byKey(const Key('admin_media_download')), findsOneWidget);
      expect(find.byKey(const Key('admin_media_auto_brand')), findsNothing);
    });
  });
}
