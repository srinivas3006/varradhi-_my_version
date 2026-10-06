import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vaaradhi/utils/share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('brand_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('a reporter photo gets the Vaaradhi sticker below it',
      (tester) async {
    final photo = img.Image(width: 800, height: 600);
    img.fill(photo, color: img.ColorRgb8(30, 120, 200));
    final bytes = Uint8List.fromList(img.encodeJpg(photo));

    File? out;
    await tester.runAsync(() async {
      out = await ShareService.brandPhotoBytes(bytes, 'vaaradhi_branded_x');
    });

    expect(out, isNotNull);
    final branded = img.decodeJpg(out!.readAsBytesSync())!;
    expect(branded.width, 800, reason: 'width kept');
    expect(branded.height, greaterThan(600),
        reason: 'the strip extends below the photo');
    // Top-left is still the photo, untouched.
    final p = branded.getPixel(5, 5);
    expect(p.b, greaterThan(150));
  });

  testWidgets('something that is not an image gives null, not a crash',
      (tester) async {
    File? out;
    await tester.runAsync(() async {
      out = await ShareService.brandPhotoBytes(
          Uint8List.fromList([1, 2, 3]), 'bad');
    });
    expect(out, isNull);
  });
}
