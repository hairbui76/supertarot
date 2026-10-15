import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supertarot_mobile/src/app_scope.dart';
import 'package:supertarot_mobile/src/data/reading_history.dart';
import 'package:supertarot_mobile/src/models/spread.dart';
import 'package:supertarot_mobile/src/models/tarot_card.dart';
import 'package:supertarot_mobile/src/screens/ask_screen.dart';
import 'package:supertarot_mobile/src/services/qa_service.dart';
import 'package:supertarot_mobile/src/theme.dart';

/// Question on top, cards picked in order below, then a reading. Runs at phone
/// width so any overflow in the pick rows or the picker sheet fails the test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en'});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    services = await AppServices.create();
    // Warm the cache outside fake async; asset IO never completes inside it.
    await services.repository.cards('en');
    await services.repository.cards('vi');
  });

  testWidgets('picks cards in order, flips one, and reads them', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: AskScreen()),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'What about my work?');
    await tester.tap(find.text('Pick cards'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('The Magician'));
    await tester.tap(find.text('Reversed').first);
    await tester.pump();
    await tester.tap(find.text('The Fool'));
    await tester.pump();
    expect(find.text('Pick cards · 2/$freeSpreadMaxCards'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    // The Fool went in reversed; flip it back upright from the list.
    await tester.tap(find.text('Reversed'));
    await tester.pump();
    expect(find.text('Upright'), findsNWidgets(2));

    await tester.tap(find.text('Interpret'));
    await tester.pumpAndSettle();

    // No API key in tests, so the answer is the per-card fallback, in order.
    final String answer = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .textSpan!
        .toPlainText();
    expect(
      answer.indexOf('1. The Magician (Upright)'),
      greaterThanOrEqualTo(0),
    );
    expect(
      answer.indexOf('2. The Fool (Upright)'),
      greaterThan(answer.indexOf('1. The Magician')),
    );

    // Saved on device straight away.
    expect(find.text('READING HISTORY · 1'), findsOneWidget);
    final List<SavedReading> saved =
        await services.history.load(services.repository);
    expect(saved.single.result.query, 'What about my work?');
    expect(saved.single.result.picks.map((CardPick p) => p.card.name),
        <String>['The Magician', 'The Fool']);
  });

  testWidgets('history survives a restart, refills the form, and deletes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final List<TarotCard> cards = await services.repository.cards('en');
    await services.history.add(
      QaResult(
        query: 'Love this month?',
        answer: 'Saved answer text',
        mode: 'openai',
        picks: <CardPick>[
          CardPick(cards[6], CardOrientation.reversed),
          CardPick(cards[17], CardOrientation.upright),
        ],
      ),
      'en',
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: AskScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('READING HISTORY · 1'), findsOneWidget);
    expect(find.text('Love this month?'), findsOneWidget);
    // Older readings start collapsed; expanding shows the full answer.
    expect(find.byType(SelectableText), findsNothing);
    // The spread dropdown uses the same icon; the history card comes last.
    await tester.tap(find.byIcon(Icons.expand_more).last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .toPlainText(),
      'Saved answer text',
    );

    await tester.ensureVisible(find.byTooltip('Ask again'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ask again'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Love this month?',
    );
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    expect(find.text('Reversed'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Delete this reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete this reading'));
    await tester.pumpAndSettle();
    expect(find.textContaining('READING HISTORY'), findsNothing);
    expect(await services.history.load(services.repository), isEmpty);
  });

  testWidgets('spread dropdown shows the description and labels positions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: AskScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final SpreadDefinition ppf = spreadById('past_present_future');
    await tester.tap(find.text('Free'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past - Present - Future · 3 cards').last);
    await tester.pumpAndSettle();

    expect(find.text(ppf.descriptionEn), findsOneWidget);
    expect(find.text('3. Future'), findsOneWidget);
    expect(find.text('Next card: 1. Past'), findsOneWidget);

    // The picker stops at three cards.
    await tester.ensureVisible(find.text('Pick cards'));
    await tester.tap(find.text('Pick cards'));
    await tester.pumpAndSettle();
    for (final String name in <String>[
      'The Fool',
      'The Magician',
      'The High Priestess',
      'The Empress',
    ]) {
      await tester.tap(find.text(name));
      await tester.pump();
    }
    expect(find.text('Pick cards · 3/3'), findsOneWidget);
    expect(find.text('This spread holds 3 cards.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('PAST'), findsOneWidget);
    expect(find.text('PRESENT'), findsOneWidget);
    expect(find.text('FUTURE'), findsOneWidget);
    expect(find.textContaining('Next card'), findsNothing);

    await tester.ensureVisible(find.text('Interpret'));
    await tester.tap(find.text('Interpret'));
    await tester.pumpAndSettle();

    final String answer = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .textSpan!
        .toPlainText();
    expect(answer, contains('1. Past - The Fool (Upright)'));
    expect(answer, contains('3. Future - The High Priestess (Upright)'));
    final List<SavedReading> saved =
        await services.history.load(services.repository);
    expect(saved.single.result.spreadId, 'past_present_future');
    // Spread name shown as a chip on the history card.
    expect(find.text('Past - Present - Future'), findsOneWidget);
  });

  testWidgets('Vietnamese Celtic Cross with ten cards fits a phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await services.settings.setLanguage('vi');
    final List<TarotCard> cards = await services.repository.cards('vi');

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: AskScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tự do'));
    await tester.pumpAndSettle();
    // Celtic Cross sits low in the menu, past what is built up front.
    await tester.scrollUntilVisible(
      find.text('Celtic Cross · 10 lá'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Celtic Cross · 10 lá').last);
    await tester.pumpAndSettle();
    expect(find.text('2. Thử thách'), findsOneWidget);

    await tester.ensureVisible(find.text('Chọn lá'));
    await tester.tap(find.text('Chọn lá'));
    await tester.pumpAndSettle();
    for (final TarotCard card in cards.take(10)) {
      await tester.ensureVisible(find.text(card.name));
      await tester.tap(find.text(card.name));
      await tester.pump();
    }
    expect(find.text('Chọn lá · 10/10'), findsOneWidget);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    expect(find.text('THỬ THÁCH'), findsOneWidget);
    expect(find.text('điều cắt ngang hoặc cản trở'), findsOneWidget);

    await tester.ensureVisible(find.text('Giải nghĩa'));
    await tester.tap(find.text('Giải nghĩa'));
    await tester.pumpAndSettle();
    expect(find.text('Celtic Cross'), findsOneWidget);
  });
}
