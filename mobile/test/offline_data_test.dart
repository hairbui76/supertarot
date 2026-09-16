import 'package:flutter_test/flutter_test.dart';
import 'package:supertarot_mobile/src/data/embedding_index.dart';
import 'package:supertarot_mobile/src/data/tarot_repository.dart';
import 'package:supertarot_mobile/src/models/reference_chunk.dart';
import 'package:supertarot_mobile/src/models/tarot_card.dart';
import 'package:supertarot_mobile/src/services/study_service.dart';

/// Exercises the bundled assets end to end: if `prepare_assets.py` has not been
/// re-run after a data change, these fail before the APK ever gets built.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final String language in <String>['vi', 'en']) {
    group('bundled $language data', () {
      test('loads all 78 cards in deck order', () async {
        final List<TarotCard> cards =
            await TarotRepository().cards(language);

        expect(cards, hasLength(78));
        expect(cards.first.name, 'The Fool');
        expect(cards[21].name, 'The World');
        expect(cards[22].name, 'Ace of Wands');
        expect(cards.last.name, 'King of Pentacles');
        expect(
          cards.every((TarotCard card) => card.imageFile.isNotEmpty),
          isTrue,
        );
      });

      test('every card exposes at least one askable facet', () async {
        final List<TarotCard> cards =
            await TarotRepository().cards(language);
        for (final TarotCard card in cards) {
          expect(
            StudyService.availableFacets(card),
            isNotEmpty,
            reason: '${card.name} has no facet with content',
          );
        }
      });

      test('embedding index matches its vector blob', () async {
        final EmbeddingIndex index = await EmbeddingIndex.load(language);
        expect(index.chunkCount, greaterThan(1000));
        expect(index.dimensions, 512);
      });

      test('search retrieves chunks for the queried card', () async {
        final EmbeddingIndex index = await EmbeddingIndex.load(language);
        final List<ReferenceChunk> results = index.search(
          'The Fool upright love',
          topK: 5,
          cardName: 'The Fool',
          orientation: 'upright',
          facet: 'love',
        );

        expect(results, isNotEmpty);
        expect(results.first.cardName, 'The Fool');
        expect(results.first.orientation, 'upright');
        expect(results.first.facet, 'love');
        expect(results.first.text, isNotEmpty);
      });

      // The shipped index uses the deterministic `hash` provider, which is
      // bag-of-words rather than semantic: an unfiltered query for one card
      // can surface a sibling card first. Assert only what the retrieval
      // layer guarantees - positive, descending scores over real text.
      test('unfiltered search returns descending positive scores', () async {
        final EmbeddingIndex index = await EmbeddingIndex.load(language);
        final List<ReferenceChunk> results =
            index.search('Queen of Cups', topK: 5);

        expect(results, hasLength(5));
        expect(results.first.score, greaterThan(0));
        for (int i = 1; i < results.length; i++) {
          expect(
            results[i].score,
            lessThanOrEqualTo(results[i - 1].score),
          );
        }
        expect(
          results.every((ReferenceChunk chunk) => chunk.text.isNotEmpty),
          isTrue,
        );
      });
    });
  }
}
