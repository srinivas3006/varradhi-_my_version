import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/screens/spotlight_screen.dart';

class _EmptyApi implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
          Future<void>? __) async =>
      ResponseBody.fromString(
        jsonEncode({'data': [], 'meta': {}, 'errors': null}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Spotlight\'s top and bottom bars are slim, targets stay 48pt',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _EmptyApi();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
        const MaterialApp(home: SpotlightScreen(isLocal: false)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Top bar: a 48pt row; the toggle pill is slimmer than before (42pt).
    final toggle = tester.getSize(find.byKey(const Key('spotlight_mode_toggle')));
    expect(toggle.height, 36);
    final profile =
        tester.getRect(find.byKey(const Key('spotlight_profile_btn')));
    expect(profile.size, const Size(48, 48), reason: 'Android 48pt touch target kept');
    // Whole top bar (no status bar in tests) is at most 56pt — was ~66.
    expect(profile.bottom, lessThanOrEqualTo(56));

    // Post button: a 36pt disc.
    expect(tester.getSize(find.byKey(const Key('spotlight_post_btn'))),
        const Size(36, 36));

    // Bottom bar: 48pt row + 2 + 2 + 4pt — was 8 + 48 + 12 = 68.
    final bottom =
        tester.getSize(find.byKey(const Key('spotlight_bottom_bar')));
    expect(bottom.height, lessThanOrEqualTo(57));
    expect(
        tester.getSize(find.byKey(const Key('spotlight_refresh_btn'))),
        const Size(48, 48));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
