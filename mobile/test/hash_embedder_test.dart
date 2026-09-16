import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supertarot_mobile/src/data/hash_embedder.dart';
import 'package:supertarot_mobile/src/models/deck_order.dart';

void main() {
  group('HashEmbedder', () {
    // Reference values produced by learning/embeddings.py:
    //   HashEmbeddingProvider(512).embed([text])[0]
    // If these drift, query vectors stop matching the bundled index.
    test('matches the Python provider on an English phrase', () {
      final Float32List vector =
          HashEmbedder().embed('The Fool upright love');
      expect(_nonZero(vector), <int, double>{
        44: -0.377964,
        46: -0.377964,
        54: -0.377964,
        150: -0.377964,
        169: 0.377964,
        178: -0.377964,
        392: -0.377964,
      });
    });

    test('matches the Python provider on Vietnamese text', () {
      final Float32List vector =
          HashEmbedder().embed('tình yêu mới và cảm lòng');
      expect(_nonZero(vector), <int, double>{
        92: -0.301511,
        162: -0.301511,
        187: 0.301511,
        248: -0.301511,
        274: -0.301511,
        312: -0.301511,
        324: -0.301511,
        357: 0.301511,
        409: 0.301511,
        472: -0.301511,
        510: -0.301511,
      });
    });

    test('returns a zero vector for text with no word characters', () {
      final Float32List vector = HashEmbedder().embed('!!! ???');
      expect(vector.every((double value) => value == 0), isTrue);
    });
  });

  group('deckPositionOf', () {
    test('orders the Major Arcana by number, not alphabetically', () {
      expect(
        deckPositionOf('The Fool').compareTo(deckPositionOf('Death')),
        lessThan(0),
      );
      expect(
        deckPositionOf('Judgement').compareTo(deckPositionOf('The World')),
        lessThan(0),
      );
    });

    test('orders minor arcana Ace through King inside each suit', () {
      expect(
        deckPositionOf('Ace of Wands')
            .compareTo(deckPositionOf('Ten of Wands')),
        lessThan(0),
      );
      expect(
        deckPositionOf('Ten of Cups').compareTo(deckPositionOf('Page of Cups')),
        lessThan(0),
      );
      expect(
        deckPositionOf('Queen of Swords')
            .compareTo(deckPositionOf('King of Swords')),
        lessThan(0),
      );
    });

    test('puts every Major Arcana card before every suit card', () {
      expect(
        deckPositionOf('The World')
            .compareTo(deckPositionOf('Ace of Wands')),
        lessThan(0),
      );
    });

    test('sorts unknown names last instead of throwing', () {
      expect(
        deckPositionOf('King of Pentacles')
            .compareTo(deckPositionOf('Nonexistent Card')),
        lessThan(0),
      );
    });
  });
}

/// Rounds to the 6 decimals the Python reference was printed with.
Map<int, double> _nonZero(Float32List vector) {
  final Map<int, double> result = <int, double>{};
  for (int i = 0; i < vector.length; i++) {
    if (vector[i] != 0) {
      result[i] = double.parse(vector[i].toStringAsFixed(6));
    }
  }
  return result;
}
