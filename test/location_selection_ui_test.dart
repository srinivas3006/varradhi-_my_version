import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/location_model.dart';
import 'package:way2news_clone/repositories/location_repository.dart';
import 'package:way2news_clone/screens/location_selection_screen.dart';
import 'package:way2news_clone/theme/app_theme.dart';

class FakeLocationRepository extends LocationRepository {
  @override
  Future<List<LocationNode>> states({int pageSize = 50}) async {
    return [
      const LocationNode(id: '1', nameEn: 'Telangana', nameTe: 'తెలంగాణ', slug: 'telangana'),
      const LocationNode(id: '2', nameEn: 'Andhra Pradesh', nameTe: 'ఆంధ్రప్రదేశ్', slug: 'andhra-pradesh'),
    ];
  }

  @override
  Future<List<LocationNode>> districts({
    String? stateSlug,
    String? stateId,
    int pageSize = 100,
  }) async {
    return [
      const LocationNode(id: 'd1', nameEn: 'Adilabad', nameTe: 'ఆదిలాబాద్', slug: 'adilabad'),
      const LocationNode(id: 'd2', nameEn: 'Hyderabad', nameTe: 'హైదరాబాద్', slug: 'hyderabad'),
    ];
  }
}

void main() {
  testWidgets('LocationSelectionScreen renders Telugu names and brand color theme', (tester) async {
    final fakeRepo = FakeLocationRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light('Telugu'),
        home: LocationSelectionScreen(repository: fakeRepo),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar Telugu title
    expect(find.text('జిల్లాను ఎంచుకోండి'), findsOneWidget);

    // Verify GPS Button text in Telugu and primary background color
    expect(find.text('నా ప్రస్తుత ప్రాంతాన్ని ఉపయోగించండి'), findsOneWidget);
    final elevatedBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(elevatedBtn.style?.backgroundColor?.resolve({}), AppColors.primary);

    // Verify Search Hint in Telugu
    expect(find.text('గ్రామం లేదా మండలం పేరుతో వెతకండి...'), findsOneWidget);

    // Verify Section header shows "తెలంగాణ లోని జిల్లాలు" (auto-loaded from current state)
    expect(find.text('తెలంగాణ లోని జిల్లాలు'), findsOneWidget);

    // Verify primary titles are in Telugu
    expect(find.text('ఆదిలాబాద్'), findsOneWidget);
    expect(find.text('హైదరాబాద్'), findsOneWidget);

    // Verify English subtitles are rendered
    expect(find.text('Adilabad'), findsOneWidget);
    expect(find.text('Hyderabad'), findsOneWidget);

    // Verify action button in Telugu
    expect(find.text('ఎంచుకోండి'), findsWidgets);

    // Verify reset breadcrumb works and returns to state selection
    expect(find.byTooltip('మొదటి నుండి ప్రారంభించండి'), findsOneWidget);
    await tester.tap(find.byTooltip('మొదటి నుండి ప్రారంభించండి'));
    await tester.pumpAndSettle();

    // Verify state selection grid with Telugu labels
    expect(find.text('రాష్ట్రాన్ని ఎంచుకోండి'), findsOneWidget);
    expect(find.text('తెలంగాణ'), findsOneWidget);
    expect(find.text('ఆంధ్రప్రదేశ్'), findsOneWidget);
  });
}
