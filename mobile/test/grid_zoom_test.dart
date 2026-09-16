import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supertarot_mobile/src/app_scope.dart';
import 'package:supertarot_mobile/src/models/tarot_card.dart';
import 'package:supertarot_mobile/src/screens/browse_screen.dart';
import 'package:supertarot_mobile/src/theme.dart';

/// The browse grid is pinch-zoomable between 1 and 5 columns, and the app bar
/// stepper does the same thing for people who never try the gesture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppServices services;
  late List<TarotCard> cards;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    services = await AppServices.create();
    cards = (await services.repository.cards('en')).take(14).toList();
  });

  Future<void> pumpGrid(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            appBar: AppBar(actions: const <Widget>[GridZoomControls()]),
            body: CardGrid(cards: cards),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Drives two pointers apart (or together) across the grid.
  Future<void> pinch(
    WidgetTester tester, {
    required bool apart,
  }) async {
    const Offset centre = Offset(200, 400);
    final TestGesture first = await tester.startGesture(centre - const Offset(20, 0));
    final TestGesture second = await tester.startGesture(centre + const Offset(20, 0));

    final double travel = apart ? 120 : -14;
    for (int step = 1; step <= 6; step++) {
      final double shift = travel * step / 6;
      await first.moveTo(centre - Offset(20 + shift, 0));
      await second.moveTo(centre + Offset(20 + shift, 0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to two columns', (WidgetTester tester) async {
    await pumpGrid(tester);
    expect(services.settings.gridColumns, 2);
  });

  testWidgets('pinching out shows fewer, larger cards',
      (WidgetTester tester) async {
    await pumpGrid(tester);
    await pinch(tester, apart: true);
    expect(services.settings.gridColumns, 1);
  });

  testWidgets('pinching in shows more, smaller cards',
      (WidgetTester tester) async {
    await pumpGrid(tester);
    await pinch(tester, apart: false);
    expect(services.settings.gridColumns, greaterThan(2));
  });

  testWidgets('stepper walks the full 1..5 range and clamps at both ends',
      (WidgetTester tester) async {
    await pumpGrid(tester);

    // zoom_out adds columns. Extra taps land on a disabled button and are
    // simply ignored, which is what the clamp should do.
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pump();
    }
    expect(services.settings.gridColumns, 5);

    for (int i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
    }
    expect(services.settings.gridColumns, 1);
  });

  testWidgets('column count survives a rebuild', (WidgetTester tester) async {
    await pumpGrid(tester);
    await services.settings.setGridColumns(4);
    await tester.pump();

    expect(services.settings.gridColumns, 4);
    expect(
      tester
          .widget<GridView>(find.byType(GridView))
          .gridDelegate is SliverGridDelegateWithFixedCrossAxisCount,
      isTrue,
    );
  });
}
