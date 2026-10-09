import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/ad_package.dart';
import 'package:vaaradhi/screens/ad_booking_screen.dart';

const _areas = [
  {'id': 'kar', 'name': 'Karimnagar Local Area'},
  {'id': 'vik', 'name': 'Vikarabad'},
];

/// Only what the backend prices: Vikarabad 7 days and 45 days, and one
/// state-wide package. Karimnagar has none.
const _options = {
  'main': [
    {'duration_days': 10, 'price': '9000.00', 'currency': 'INR'},
  ],
  'local': [
    {
      'area': {'id': 'vik', 'name': 'Vikarabad'},
      'options': [
        {'duration_days': 45, 'price': '6000.00', 'currency': 'INR'},
        {'duration_days': 7, 'price': '1500.00', 'currency': 'INR'},
      ],
    },
    {'area': {'id': 'kar', 'name': 'Karimnagar Local Area'}, 'options': []},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalog comes only from the backend', () {
    test('grouped reply: areas with packages, durations sorted', () {
      final c = AdPricingCatalog.parse(_options, areas: _areas);
      expect(c.localByArea.keys, ['vik'], reason: 'Karimnagar has no price');
      expect(c.localByArea['vik']!.map((p) => p.durationDays), [7, 45]);
      expect(c.main.single.durationDays, 10);
      expect(c.localByArea['vik']!.first.priceLabel, '₹1500');
    });

    test('flat rows are read too', () {
      final c = AdPricingCatalog.parse([
        {
          'ad_type': 'local',
          'area_id': 'vik',
          'duration_days': 7,
          'price': '1500.00',
          'currency': 'INR'
        },
        {'ad_type': 'main', 'duration_days': 30, 'price': 20000, 'currency': 'INR'},
        {'ad_type': 'local', 'area_id': 'vik', 'duration_days': 0, 'price': 1},
      ], areas: _areas);
      expect(c.localByArea['vik']!.single.durationDays, 7);
      expect(c.main.single.priceLabel, '₹20000');
    });

    test('nothing priced / endpoint missing → empty', () {
      expect(AdPricingCatalog.parse(null).isEmpty, isTrue);
      expect(AdPricingCatalog.parse({'main': [], 'local': []}).isEmpty, isTrue);
    });

    test('duration hints are derived, not assumed', () {
      AdPackage p(int d) =>
          AdPackage(adType: 'main', durationDays: d, price: '1', currency: 'INR');
      expect(p(7).durationHint, '1 వారం');
      expect(p(14).durationHint, '2 వారాలు');
      expect(p(30).durationHint, '1 నెల');
      expect(p(10).durationHint, isNull);
    });
  });

  test('the exact reply the backend sent parses as expected', () {
    final c = AdPricingCatalog.parse({
      'main': [
        {'duration_days': 7, 'price': '5000.00', 'currency': 'INR'}
      ],
      'local': [
        {
          'area': {
            'id': '49330c1f-bfee-4b2c-8204-a55f85255154',
            'name': 'Vikarabad'
          },
          'options': [
            {'duration_days': 7, 'price': '1500.00', 'currency': 'INR'}
          ]
        }
      ]
    });
    expect(c.main.single.priceLabel, '₹5000');
    final vik = c.localByArea['49330c1f-bfee-4b2c-8204-a55f85255154']!;
    expect(vik.single.areaName, 'Vikarabad');
    expect(vik.single.priceLabel, '₹1500');
  });

  group('booking screen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<Map<String, dynamic>?> pumpScreen(WidgetTester tester,
        {dynamic options = _options}) async {
      tester.view.physicalSize = const Size(1080, 5400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Map<String, dynamic>? sent;
      await tester.pumpWidget(MaterialApp(
        home: AdBookingScreen(
          areasLoader: () async => _areas,
          optionsLoader: () async => options,
          submitter: (payload) async {
            sent = payload;
            return {'id': 'bk-1', 'quoted_price': '1500.00', 'currency': 'INR'};
          },
        ),
      ));
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('no 7/14/30 of its own: only the backend packages show',
        (tester) async {
      await pumpScreen(tester);
      expect(find.byKey(const Key('ad_area_vik')), findsOneWidget);
      expect(find.byKey(const Key('ad_area_kar')), findsNothing);
      expect(find.byKey(const Key('ad_pkg_local_vik_7')), findsOneWidget);
      expect(find.byKey(const Key('ad_pkg_local_vik_45')), findsOneWidget);
      expect(find.text('14 రోజులు'), findsNothing);
      expect(find.text('30 రోజులు'), findsNothing);
    });

    testWidgets('pick a package → its area, duration and price are booked',
        (tester) async {
      Map<String, dynamic>? sent;
      tester.view.physicalSize = const Size(1080, 5400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AdBookingScreen(
          areasLoader: () async => _areas,
          optionsLoader: () async => _options,
          submitter: (payload) async {
            sent = payload;
            return {'id': 'bk-1', 'quoted_price': '1500.00', 'currency': 'INR'};
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Book is off until a package is chosen.
      final book = find.byKey(const Key('ad_book_submit'));
      expect(tester.widget<ElevatedButton>(book).onPressed, isNull);

      await tester.tap(find.byKey(const Key('ad_pkg_local_vik_7')));
      await tester.pumpAndSettle();
      expect(find.text('₹1500'), findsWidgets);

      await tester.enterText(find.byType(TextFormField).at(0), 'Ravi Mobiles');
      await tester.enterText(find.byType(TextFormField).at(1), 'Ravi');
      await tester.enterText(find.byType(TextFormField).at(2), '9876543210');
      await tester.tap(book);
      await tester.pumpAndSettle();

      expect(sent!['ad_type'], 'local');
      expect(sent!['area_id'], 'vik');
      expect(sent!['duration_days'], 7);
      expect(find.text('ప్రకటన బుకింగ్ సమర్పించబడింది!'), findsOneWidget);
    });

    testWidgets('a main booking sends area_id null', (tester) async {
      Map<String, dynamic>? sent;
      tester.view.physicalSize = const Size(1080, 5400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AdBookingScreen(
          areasLoader: () async => _areas,
          optionsLoader: () async => _options,
          submitter: (payload) async {
            sent = payload;
            return {'id': 'bk-2'};
          },
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ad_type_main')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ad_pkg_main_main_10')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Ravi Mobiles');
      await tester.enterText(find.byType(TextFormField).at(1), 'Ravi');
      await tester.enterText(find.byType(TextFormField).at(2), '9876543210');
      await tester.tap(find.byKey(const Key('ad_book_submit')));
      await tester.pumpAndSettle();
      expect(sent!['ad_type'], 'main');
      expect(sent!.containsKey('area_id'), isTrue);
      expect(sent!['area_id'], isNull);
      expect(sent!['duration_days'], 10);
    });

    testWidgets('several areas → pick one from the dropdown, see its prices',
        (tester) async {
      const multi = {
        'local': [
          {
            'area': {'id': 'vik', 'name': 'Vikarabad'},
            'options': [
              {'duration_days': 7, 'price': '1500.00', 'currency': 'INR'},
            ],
          },
          {
            'area': {'id': 'kar', 'name': 'Karimnagar Local Area'},
            'options': [
              {'duration_days': 30, 'price': '3000.00', 'currency': 'INR'},
              {'duration_days': 7, 'price': '1000.00', 'currency': 'INR'},
            ],
          },
        ],
      };
      await pumpScreen(tester, options: multi);

      // No long list of cards: only the dropdown until an area is chosen.
      expect(find.byKey(const Key('ad_area_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('ad_area_vik')), findsNothing);
      expect(find.byKey(const Key('ad_area_kar')), findsNothing);

      await tester.tap(find.byKey(const Key('ad_area_dropdown')));
      await tester.pumpAndSettle();
      // The menu shows each area with its lowest price.
      expect(find.text('₹1000 నుండి'), findsWidgets);
      await tester.tap(find.text('Karimnagar Local Area').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ad_area_kar')), findsOneWidget);
      expect(find.byKey(const Key('ad_pkg_local_kar_30')), findsOneWidget);
      expect(find.byKey(const Key('ad_pkg_local_vik_7')), findsNothing);

      await tester.tap(find.byKey(const Key('ad_pkg_local_kar_30')));
      await tester.pumpAndSettle();
      expect(find.text('₹3000'), findsWidgets);

      // Switching area drops the package picked for the other one.
      await tester.tap(find.byKey(const Key('ad_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vikarabad').last);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ElevatedButton>(find.byKey(const Key('ad_book_submit')))
              .onPressed,
          isNull);
    });

    testWidgets('main packages come from the backend too', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('ad_type_main')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ad_pkg_main_main_10')), findsOneWidget);
    });

    testWidgets('endpoint not live → clear message, no made-up options',
        (tester) async {
      await pumpScreen(tester, options: null);
      expect(find.byKey(const Key('ad_packages_unavailable')), findsOneWidget);
      expect(find.byKey(const Key('ad_book_submit')), findsNothing);
    });
  });
}
