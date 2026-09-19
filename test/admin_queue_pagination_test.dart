import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final controller = File(
          'lib/features/admin/presentation/controllers/admin_ugc_queue_controller.dart')
      .readAsStringSync();
  final tab = File(
          'lib/features/admin/presentation/screens/tabs/admin_queue_tab.dart')
      .readAsStringSync();
  final dialog = File(
          'lib/features/admin/presentation/widgets/dialogs/admin_reject_dialog.dart')
      .readAsStringSync();

  String body(String src, String marker, [int len = 2600]) {
    final i = src.indexOf(marker);
    return src.substring(i, i + len > src.length ? src.length : i + len);
  }

  group('a failed page is reported, not disguised as success', () {
    final loadMore = body(controller, 'Future<void> loadMore()');

    test('loadMore sets error, not loaded', () {
      expect(loadMore, contains('_status = AdminLoadStatus.error'));
      expect(loadMore, contains('_errorMessage = e.toString()'));
    });

    test('the failure is not swallowed', () {
      expect(loadMore, isNot(contains('} catch (_) {')));
    });
  });

  group('a failure stops the scroll listener re-requesting', () {
    test('loadMore refuses to run again while in error', () {
      final loadMore = body(controller, 'Future<void> loadMore()');
      expect(loadMore, contains('if (_status == AdminLoadStatus.error) return'),
          reason: 'otherwise every scroll fires another failing request');
    });

    test('a deliberate retry path exists', () {
      expect(controller, contains('Future<void> retryLoadMore()'));
      expect(tab, contains('c.retryLoadMore'));
    });
  });

  group('a failed page does not discard loaded pages', () {
    test('the full-screen error is gated on an empty list', () {
      expect(
        tab,
        contains('c.status == AdminLoadStatus.error && c.items.isEmpty'),
        reason: 'a moderator mid-queue must not lose the rows on screen',
      );
    });

    test('the list renders an inline retry footer instead', () {
      final footer = body(tab, 'if (index >= items.length)');
      expect(footer, contains('AdminLoadStatus.error'));
      expect(footer, contains('retryLoadMore'));
    });
  });

  group('a failed reject tells the moderator', () {
    test('the error is captured rather than discarded', () {
      expect(dialog, isNot(contains('} catch (_) {')));
      expect(dialog, contains('_error = e.toString()'));
    });

    test('and is rendered in the dialog', () {
      expect(dialog, contains('if (_error != null)'));
    });
  });

  group('every paginating admin controller behaves the same', () {
    const base = 'lib/features/admin/presentation/controllers/';
    const controllers = [
      'admin_ugc_queue_controller.dart',
      'admin_reports_controller.dart',
      'admin_logs_controller.dart',
      'admin_otp_deliveries_controller.dart',
    ];

    for (final name in controllers) {
      test('$name reports a failed page instead of faking success', () {
        final src = File(base + name).readAsStringSync();
        final i = src.indexOf('Future<void> loadMore()');
        final fn = src.substring(i, i + 2600 > src.length ? src.length : i + 2600);

        expect(fn, contains('_status = AdminLoadStatus.error'));
        expect(fn, isNot(contains('} catch (_) {')));
        expect(fn, contains('if (_status == AdminLoadStatus.error) return'));
        expect(src, contains('Future<void> retryLoadMore()'));
      });
    }

    const tabs = [
      'admin_queue_tab.dart',
      'admin_reports_tab.dart',
      'admin_logs_tab.dart',
      'admin_otp_tab.dart',
    ];

    for (final name in tabs) {
      test('$name keeps loaded rows when a later page fails', () {
        final src = File(
                'lib/features/admin/presentation/screens/tabs/' + name)
            .readAsStringSync();
        expect(src,
            contains('c.status == AdminLoadStatus.error && c.items.isEmpty'));
        expect(src, contains('retryLoadMore'));
      });
    }
  });

  group('a deliberate fallback is not mistaken for a swallowed error', () {
    test('the reporter profile fallback is logged', () {
      final src = File(
              'lib/features/admin/presentation/controllers/admin_reporter_profile_controller.dart')
          .readAsStringSync();
      expect(src, isNot(contains('} catch (_) {')));
      expect(src, contains('using fallback'));
    });
  });

  group('uploader blocking is reachable from the detail screen', () {
    final screen = File(
            'lib/features/admin/presentation/screens/admin_ugc_detail_screen.dart')
        .readAsStringSync();
    final controller = File(
            'lib/features/admin/presentation/controllers/admin_ugc_detail_controller.dart')
        .readAsStringSync();

    test('the controller implements both directions', () {
      expect(controller, contains('Future<void> blockUploader()'));
      expect(controller, contains('Future<void> unblockUploader()'));
    });

    test('the screen actually calls them', () {
      // Regression: both existed on the controller and the API, but nothing
      // in the UI invoked them — a moderator could only nudge trust.
      expect(screen, contains('_controller.blockUploader()'));
      expect(screen, contains('_controller.unblockUploader()'));
    });

    test('blocking is confirmed before it happens', () {
      final fn = screen.substring(screen.indexOf('_toggleUploaderBlock(bool'));
      expect(fn.substring(0, 1500), contains('showDialog<bool>'));
      expect(fn.substring(0, 1500), contains('if (confirmed != true) return'));
    });

    test('unblocking skips the confirmation', () {
      final fn = screen.substring(screen.indexOf('_toggleUploaderBlock(bool'));
      expect(fn.substring(0, 800), contains('if (!currentlyBlocked)'),
          reason: 'only the destructive direction needs confirming');
    });

    test('a failed block is reported, not swallowed', () {
      final fn = screen.substring(screen.indexOf('_toggleUploaderBlock(bool'));
      expect(fn, contains('విఫలమైంది'));
      expect(fn, isNot(contains('} catch (_) {')));
    });

    test('the icon reflects the current blocked state', () {
      expect(screen, contains('s.uploaderBlocked'));
      expect(screen, contains('Icons.lock_open_rounded'));
      expect(screen, contains('Icons.block_rounded'));
    });
  });
}
