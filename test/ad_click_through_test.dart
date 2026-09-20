import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  group('Android 11+ package visibility lets a click-through resolve', () {
    // Root cause: <queries> declared only PROCESS_TEXT, so canLaunchUrl()
    // could not see a browser and returned false. Every ad widget guards on
    // it, so a tap with a valid destination_url silently did nothing.
    test('https is declared', () {
      expect(manifest, contains('<queries>'));
      final queries = manifest.substring(
          manifest.indexOf('<queries>'), manifest.indexOf('</queries>'));
      expect(queries, contains('android.intent.action.VIEW'));
      expect(queries, contains('android:scheme="https"'));
    });

    test('http is declared too', () {
      final queries = manifest.substring(
          manifest.indexOf('<queries>'), manifest.indexOf('</queries>'));
      expect(queries, contains('android:scheme="http"'));
    });

    test('whatsapp is declared for wa.me links', () {
      final queries = manifest.substring(
          manifest.indexOf('<queries>'), manifest.indexOf('</queries>'));
      expect(queries, contains('com.whatsapp'));
    });
  });

  group('a spotlight ad click is not swallowed', () {
    final card = File('lib/widgets/ads/sponsored_spotlight_ad_card.dart')
        .readAsStringSync();
    final handler = card.substring(card.indexOf('_handleAdTap()'));
    final body = handler.substring(0, 1400);

    test('it no longer gates the launch on canLaunchUrl', () {
      expect(body, isNot(contains('await canLaunchUrl')),
          reason: 'that guard is what silently dropped valid clicks');
    });

    test('it attempts the launch and falls back in-app', () {
      expect(body, contains('LaunchMode.externalApplication'));
      expect(body, contains('LaunchMode.inAppBrowserView'));
    });

    test('a failure is logged rather than discarded', () {
      expect(body, contains('could not open'));
    });

    test('an empty destination still does nothing, by design', () {
      expect(card, contains('if (widget.ad.destinationUrl.isEmpty) return;'));
    });

    test('the click is still recorded for reporting', () {
      expect(card, contains('recordClick'));
    });
  });
}
