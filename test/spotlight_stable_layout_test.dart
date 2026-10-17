import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

/// The story from the two screenshots (about 500 letters).
const _story =
    'భూమి ఆరోగ్యంపై శాస్త్రవేత్తలు తీవ్ర ఆందోళన వ్యక్తం చేస్తున్నారు. 2026 క్లైమేట్ నివేదిక ప్రకారం.. భూమికి సంబంధించిన 7 కీలక వాతావరణ సూచికలు రికార్డు స్థాయికి చేరాయి. వాతావరణంలో కార్బన్ డయాక్సైడ్ స్థాయిలు 428 పీపీఎంకు చేరగా, భూతాపం పెరుగుదల వేగం కూడా రెట్టింపునకు పైగా పెరిగింది. సముద్రాలు వేడెక్కడం, హిమానీనదాలు కరగడం, సముద్ర మట్టాలు పెరగడం ఆందోళన కలిగిస్తున్నాయి. అయితే, అమెజాన్ అడవుల్లో అటవీ నిర్మూలన తగ్గడం, సౌర, పవన విద్యుత్ వినియోగం పెరగడం సానుకూల పరిణామాలని శాస్త్రవేత్తలు వెల్లడించారు.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = 'Telugu';
  });

  /// Lays the card out on a phone of [size] (logical px) and returns how
  /// much of the story shows and the body's size relative to the screen.
  Future<({bool cut, double sizeToWidth, double fill})> layout(
      WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightNewsCard(
          article: NewsArticle.fromJson({
            'id': 's',
            'title': 'భూమికి జ్వరం.. ప్రమాదకర స్థాయికి చేరిన 7 సూచికలు',
            'content': _story,
            'feed_item_type': 'ugc',
            'published_at': DateTime.now().toIso8601String(),
          }),
          onTap: () {},
          onShare: () {},
          onClose: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    final p = tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .firstWhere((p) => p.text.toPlainText().startsWith('భూమి ఆరోగ్యంపై'));
    final style = p.text.style ??
        (p.text as TextSpan).children!.first.style ??
        const TextStyle();
    final fontSize = style.fontSize ?? 0;
    final result = (
      cut: p.didExceedMaxLines,
      // The card is laid out at the reference width and scaled, so the
      // size relative to the screen is the size over that width.
      sizeToWidth: fontSize / SpotlightNewsCard.typeReferenceWidth,
      fill: p.size.height,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
    return result;
  }

  testWidgets('the same story shows whole on narrow and wide phones',
      (tester) async {
    // Like the two phones in the screenshots: a narrow tall one and a
    // wide-set one.
    // The bundled Telugu fonts finish loading after a first layout (in the
    // app the card re-fits when they arrive).
    await layout(tester, const Size(360, 800));
    final narrow = await layout(tester, const Size(360, 800));
    final wide = await layout(tester, const Size(432, 930));
    expect(narrow.cut, isFalse, reason: 'no "విద్యు…" mid-word cut');
    expect(wide.cut, isFalse);
    // Same look: text size relative to the screen stays within the fitting
    // band, not the old capped ±10% gap plus a cut.
    final ratio = narrow.sizeToWidth / wide.sizeToWidth;
    expect(ratio, inInclusiveRange(0.95, 1.05));
    expect((narrow.fill - wide.fill).abs(), lessThan(12),
        reason: 'the story fills the same share of the card');
  });
}
