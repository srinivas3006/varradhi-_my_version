import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/widgets/feed/daily_greeting_widget.dart';

const _quote =
    '"దేవి నవరాత్రులు శుభాకాంక్షలు “అమ్మవారి ఆశీస్సులు ఉంటే ప్రతి కష్టం ఓర్పుగా మారుతుంది.. ప్రతి కన్నీరు ఆనందంగా మారుతుంది.. ప్రతి అడుగు విజయానికి దారి చూపుతుంది. జగన్మాత దుర్గాదేవి ఆశీస్సులు అందరిపై ఉండాలని కోరుకుంటూ.. జై మాతా దీ!"';

void main() {
  test('"Unknown" or no author shows the Telugu heading', () {
    expect(DailyGreetingWidget.headingFor('Unknown'), 'నేటి సూక్తి');
    expect(DailyGreetingWidget.headingFor(''), 'నేటి సూక్తి');
    expect(DailyGreetingWidget.headingFor('Swami Vivekananda'),
        'Swami Vivekananda');
  });

  test('quotation marks are not doubled', () {
    expect(DailyGreetingWidget.quoteText(_quote), _quote);
    expect(DailyGreetingWidget.quoteText('Be kind'), '“Be kind”');
  });

  testWidgets('the whole quote shows, not two lines', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DailyGreetingWidget(
              imageUrl: '', title: 'Unknown', quote: _quote),
        ),
      ),
    ));
    final text = tester.widget<Text>(find.byKey(const Key('daily_quote_text')));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('నేటి సూక్తి'), findsOneWidget);
  });
}
