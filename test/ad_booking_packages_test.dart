import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/ad_package.dart';
import 'package:vaaradhi/screens/ad_booking_screen.dart';

/// GET /api/v1/ads/pricing/options/ as the backend handover describes it.
const _options = {
  'coverage_options': {
    'global': [
      {'duration_days': 7, 'price': '5000.00', 'currency': 'INR'},
    ],
    'state': [
      {
        'area': {
          'id': 'ap',
          'name': 'Andhra Pradesh',
          'coverage_level': 'state',
        },
        'options': [
          {'duration_days': 7, 'price': '2500.00', 'currency': 'INR'},
        ],
      },
    ],
    'local': [
      {
        'area': {
          'id': 'vik',
          'name': 'Vikarabad',
          'coverage_level': 'district',
        },
        'options': [
          {'duration_days': 15, 'price': '1500.00', 'currency': 'INR'},
          {'duration_days': 7, 'price': '1000.00', 'currency': 'INR'},
        ],
      },
      {
        'area': {'id': 'kar', 'name': 'Karimnagar'},
        'options': [
          {'duration_days': 30, 'price': '3000.00', 'currency': 'INR'},
        ],
      },
    ],
  },
  'ad_formats': [
    {'value': 'banner', 'label': 'Banner'},
    {'value': 'video', 'label': 'Video'},
    {'value': 'poster', 'label': 'Poster'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalog comes only from the backend', () {
    test('coverage_options: global, state and local, durations sorted', () {
      final c = AdPricingCatalog.parse(_options);
      expect(c.global.single.priceLabel, '₹5000');
      expect(c.stateByArea.keys, ['ap']);
      expect(c.stateByArea['ap']!.single.priceLabel, '₹2500');
      expect(c.localByArea.keys, ['vik', 'kar']);
      expect(c.localByArea['vik']!.map((p) => p.durationDays), [7, 15]);
      expect(c.areaNames['vik'], 'Vikarabad');
      expect(c.formats.map((f) => f.value), ['banner', 'video', 'poster']);
      expect(c.formats.first.label, 'Banner');
    });

    test('the older main/local reply still reads (main = global)', () {
      final c = AdPricingCatalog.parse({
        'main': [
          {'duration_days': 10, 'price': '9000.00', 'currency': 'INR'}
        ],
        'local': [
          {
            'area': {'id': 'vik', 'name': 'Vikarabad'},
            'options': [
              {'duration_days': 7, 'price': '1500.00', 'currency': 'INR'}
            ]
          },
          {
            'area': {'id': 'kar', 'name': 'Karimnagar'},
            'options': []
          },
        ],
      });
      expect(c.global.single.durationDays, 10);
      expect(c.localByArea.keys, ['vik'], reason: 'Karimnagar has no price');
      expect(c.stateByArea, isEmpty);
    });

    test('flat rows are read too', () {
      final c = AdPricingCatalog.parse([
        {
          'scope': 'state',
          'area_id': 'ap',
          'duration_days': 7,
          'price': '2500.00',
        },
        {'ad_type': 'main', 'duration_days': 30, 'price': 20000},
        {'ad_type': 'local', 'area_id': 'vik', 'duration_days': 0, 'price': 1},
      ]);
      expect(c.stateByArea['ap']!.single.durationDays, 7);
      expect(c.global.single.priceLabel, '₹20000');
      expect(c.localByArea, isEmpty);
    });

    test('nothing priced / endpoint missing → empty', () {
      expect(AdPricingCatalog.parse(null).isEmpty, isTrue);
      expect(
          AdPricingCatalog.parse({
            'coverage_options': {'global': [], 'state': [], 'local': []}
          }).isEmpty,
          isTrue);
    });

    test('duration hints are derived, not assumed', () {
      AdPackage p(int d) => AdPackage(
          scope: AdScope.global, durationDays: d, price: '1', currency: 'INR');
      expect(p(7).durationHint, '1 వారం');
      expect(p(14).durationHint, '2 వారాలు');
      expect(p(30).durationHint, '1 నెల');
      expect(p(10).durationHint, isNull);
    });
  });

  group('booking errors', () {
    test('400 field messages, from the envelope or the bare body', () {
      final a = AdBookingError.from(400, {
        'data': null,
        'errors': {
          'code': 400,
          'message': 'An error occurred.',
          'details': {
            'area_id': ['Select a state-level area for state bookings.']
          },
        },
      });
      expect(
          a.fields['area_id'], 'Select a state-level area for state bookings.');
      expect(a.message, 'Select a state-level area for state bookings.');

      final b = AdBookingError.from(400, {
        'duration_days': [
          'No active pricing is available for the selected area and duration.'
        ]
      });
      expect(b.fields['duration_days'], contains('No active pricing'));
    });

    test('404 reloads options; 5xx and offline offer retry; 429 waits', () {
      expect(AdBookingError.from(404, null).refreshOptions, isTrue);
      expect(AdBookingError.from(503, null).retryable, isTrue);
      expect(AdBookingError.from(null, null).retryable, isTrue);
      expect(AdBookingError.from(429, null).message, contains('అభ్యర్థనలు'));
      expect(AdBookingError.from(401, null).message, contains('లాగిన్'));
    });
  });

  group('booking screen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<List<Map<String, dynamic>>> pumpScreen(WidgetTester tester,
        {dynamic options = _options,
        Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
            submitter}) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final sent = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: AdBookingScreen(
          areasLoader: () async => const [],
          optionsLoader: () async => options,
          submitter: (payload) async {
            sent.add(payload);
            if (submitter != null) return submitter(payload);
            return {
              'id': 'booking-uuid-1',
              'status': 'pending',
              'scope': payload['scope'],
              'ad_format': payload['ad_format'],
              'area': {'id': 'vik', 'name': 'Vikarabad'},
              'duration_days': payload['duration_days'],
              'quoted_price': '1500.00',
              'currency': 'INR',
              'whatsapp_url': 'https://wa.me/910000000000',
            };
          },
        ),
      ));
      await tester.pumpAndSettle();
      return sent;
    }

    Future<void> chooseFormat(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const Key('ad_format_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> chooseArea(
        WidgetTester tester, String scope, String name) async {
      await tester.tap(find.byKey(Key('ad_area_dropdown_$scope')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    Future<void> fillDetails(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(0), 'Ganesh Stores');
      await tester.enterText(find.byType(TextFormField).at(1), 'Ganesh');
      await tester.enterText(find.byType(TextFormField).at(2), '9876543210');
    }

    testWidgets('local: area dropdown shows only local areas and their prices',
        (tester) async {
      final sent = await pumpScreen(tester);
      expect(find.byKey(const Key('ad_scope_local')), findsOneWidget);
      // Several local areas → nothing picked until the advertiser chooses.
      expect(find.byKey(const Key('ad_pkg_local_vik_7')), findsNothing);

      await tester.tap(find.byKey(const Key('ad_area_dropdown_local')));
      await tester.pumpAndSettle();
      expect(find.text('Andhra Pradesh'), findsNothing,
          reason: 'state areas are not offered under local');
      await tester.tap(find.text('Vikarabad').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ad_pkg_local_vik_7')), findsOneWidget);
      expect(find.byKey(const Key('ad_pkg_local_vik_15')), findsOneWidget);
      expect(find.byKey(const Key('ad_pkg_local_kar_30')), findsNothing);

      await chooseFormat(tester, 'Poster');
      await tester.tap(find.byKey(const Key('ad_pkg_local_vik_15')));
      await tester.pumpAndSettle();
      await fillDetails(tester);
      await tester.tap(find.byKey(const Key('ad_book_submit')));
      await tester.pumpAndSettle();

      final p = sent.single;
      expect(p['scope'], 'local');
      expect(p['ad_format'], 'poster');
      expect(p['area_id'], 'vik');
      expect(p['duration_days'], 15);
      expect(p['advertiser_name'], 'Ganesh');
      expect(p.containsKey('ad_type'), isFalse);

      // Confirmation: booking ID, quoted price, WhatsApp.
      expect(find.text('ప్రకటన బుకింగ్ సమర్పించబడింది!'), findsOneWidget);
      expect(find.text('booking-uuid-1'), findsOneWidget);
      expect(find.text('₹1500'), findsOneWidget);
      expect(find.byKey(const Key('ad_booking_whatsapp')), findsOneWidget);
    });

    testWidgets('global: no location field and no area_id sent',
        (tester) async {
      final sent = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('ad_scope_global')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ad_area_dropdown_global')), findsNothing);
      expect(find.byKey(const Key('ad_area_dropdown_local')), findsNothing);

      await chooseFormat(tester, 'Banner');
      await tester.tap(find.byKey(const Key('ad_pkg_global_all_7')));
      await tester.pumpAndSettle();
      await fillDetails(tester);
      await tester.tap(find.byKey(const Key('ad_book_submit')));
      await tester.pumpAndSettle();

      expect(sent.single['scope'], 'global');
      expect(sent.single.containsKey('area_id'), isFalse);
      expect(sent.single['ad_format'], 'banner');
    });

    testWidgets('state: only state areas; a single one is preselected',
        (tester) async {
      final sent = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('ad_scope_state')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ad_pkg_state_ap_7')), findsOneWidget);

      await chooseFormat(tester, 'Video');
      await tester.tap(find.byKey(const Key('ad_pkg_state_ap_7')));
      await tester.pumpAndSettle();
      await fillDetails(tester);
      await tester.tap(find.byKey(const Key('ad_book_submit')));
      await tester.pumpAndSettle();
      expect(sent.single['scope'], 'state');
      expect(sent.single['area_id'], 'ap');
      expect(sent.single['ad_format'], 'video');
    });

    testWidgets('format is required when the backend offers formats',
        (tester) async {
      final sent = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('ad_scope_global')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ad_pkg_global_all_7')));
      await tester.pumpAndSettle();
      await fillDetails(tester);
      await tester.tap(find.byKey(const Key('ad_book_submit')));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(find.text('ప్రకటన రకాన్ని ఎంచుకోండి.'), findsWidgets);
    });

    testWidgets('400: backend message under the field, form kept',
        (tester) async {
      await pumpScreen(tester, submitter: (_) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/ads/bookings/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/ads/bookings/'),
            statusCode: 400,
            data: {
              'errors': {
                'details': {
                  'duration_days': [
                    'No active pricing is available for the selected area and duration.'
                  ]
                }
              }
            },
          ),
        );
      });
      await tester.tap(find.byKey(const Key('ad_scope_global')));
      await tester.pumpAndSettle();
      await chooseFormat(tester, 'Banner');
      await tester.tap(find.byKey(const Key('ad_pkg_global_all_7')));
      await tester.pumpAndSettle();
      await fillDetails(tester);
      await tester.tap(find.byKey(const Key('ad_book_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No active pricing'), findsWidgets);
      expect(find.text('Ganesh Stores'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
    });

    testWidgets('offline: form kept and Retry offered', (tester) async {
      var calls = 0;
      final sent = await pumpScreen(tester, submitter: (p) async {
        calls++;
        if (calls == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionTimeout,
          );
        }
        return {'id': 'bk-2', 'quoted_price': '5000.00', 'currency': 'INR'};
      });
      await tester.tap(find.byKey(const Key('ad_scope_global')));
      await tester.pumpAndSettle();
      await chooseFormat(tester, 'Banner');
      await tester.tap(find.byKey(const Key('ad_pkg_global_all_7')));
      await tester.pumpAndSettle();
      await fillDetails(tester);
      await tester.tap(find.byKey(const Key('ad_book_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ad_booking_retry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ad_booking_retry')));
      await tester.pumpAndSettle();
      expect(sent.length, 2);
      expect(find.text('bk-2'), findsOneWidget);
      // No whatsapp_url in the reply → no WhatsApp button.
      expect(find.byKey(const Key('ad_booking_whatsapp')), findsNothing);
    });

    testWidgets('endpoint not live → clear message, no made-up options',
        (tester) async {
      await pumpScreen(tester, options: null);
      expect(find.byKey(const Key('ad_packages_unavailable')), findsOneWidget);
      expect(find.byKey(const Key('ad_book_submit')), findsNothing);
    });
  });
}
