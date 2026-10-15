import 'package:flutter_test/flutter_test.dart';
import 'package:supertarot_mobile/src/models/spread.dart';

void main() {
  test('spread ids are unique and free comes first', () {
    final List<String> ids =
        tarotSpreads.map((SpreadDefinition s) => s.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(tarotSpreads.first.id, 'free');
    expect(tarotSpreads.first.isFree, isTrue);
    expect(tarotSpreads.where((SpreadDefinition s) => s.isFree), hasLength(1));
  });

  test('every spread and position is written in both languages', () {
    for (final SpreadDefinition spread in tarotSpreads) {
      for (final String language in <String>['vi', 'en']) {
        expect(spread.name(language), isNotEmpty, reason: spread.id);
        expect(spread.description(language), isNotEmpty, reason: spread.id);
        for (final SpreadPosition position in spread.positions) {
          expect(position.label(language), isNotEmpty, reason: spread.id);
        }
      }
      // A hint in one language and not the other would read oddly.
      for (final SpreadPosition position in spread.positions) {
        expect(position.hintVi.isEmpty, position.hintEn.isEmpty,
            reason: '${spread.id}: ${position.en}');
      }
    }
  });

  test('card limits follow the layout', () {
    expect(spreadById('free').maxCards, freeSpreadMaxCards);
    expect(spreadById('one_card').maxCards, 1);
    expect(spreadById('past_present_future').maxCards, 3);
    expect(spreadById('celtic_cross').maxCards, 10);
    expect(spreadById('astrology_12').maxCards, 12);
    expect(spreadById('year_ahead').maxCards, 13);
  });

  test('unknown or missing ids fall back to the free layout', () {
    expect(spreadById(null).id, 'free');
    expect(spreadById('no-such-spread').id, 'free');
  });
}
