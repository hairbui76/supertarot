/// Traditional tarot deck ordering, mirroring `learning/deck_order.py`.
///
/// The bundled JSON is alphabetical because the source site lists it that way.
/// Card names are English in both the EN and VI datasets, so one table covers
/// both languages.
const List<String> majorArcanaOrder = <String>[
  'The Fool',
  'The Magician',
  'The High Priestess',
  'The Empress',
  'The Emperor',
  'The Hierophant',
  'The Lovers',
  'The Chariot',
  'Strength',
  'The Hermit',
  'The Wheel of Fortune',
  'Justice',
  'The Hanged Man',
  'Death',
  'Temperance',
  'The Devil',
  'The Tower',
  'The Star',
  'The Moon',
  'The Sun',
  'Judgement',
  'The World',
];

const List<String> suitOrder = <String>['Wands', 'Cups', 'Swords', 'Pentacles'];

const List<String> rankOrder = <String>[
  'Ace',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Page',
  'Knight',
  'Queen',
  'King',
];

/// Sort key for a card name: group first (Major Arcana, then each suit),
/// then position inside that group.
class DeckPosition implements Comparable<DeckPosition> {
  const DeckPosition(this.group, this.position, this.name);

  final int group;
  final int position;
  final String name;

  @override
  int compareTo(DeckPosition other) {
    if (group != other.group) {
      return group.compareTo(other.group);
    }
    if (position != other.position) {
      return position.compareTo(other.position);
    }
    return name.compareTo(other.name);
  }
}

final Map<String, int> _majorIndex = <String, int>{
  for (int i = 0; i < majorArcanaOrder.length; i++)
    majorArcanaOrder[i].toLowerCase(): i,
};
final Map<String, int> _suitIndex = <String, int>{
  for (int i = 0; i < suitOrder.length; i++) suitOrder[i].toLowerCase(): i,
};
final Map<String, int> _rankIndex = <String, int>{
  for (int i = 0; i < rankOrder.length; i++) rankOrder[i].toLowerCase(): i,
};

const int _majorGroup = 0;
const int _minorGroupOffset = 1;
// Unknown names sort last instead of throwing, so a data typo degrades to an
// alphabetical tail rather than breaking the browser.
final int _unknownGroup = _minorGroupOffset + suitOrder.length;

DeckPosition deckPositionOf(String name) {
  final String cleaned = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  final String folded = cleaned.toLowerCase();

  final int? major = _majorIndex[folded];
  if (major != null) {
    return DeckPosition(_majorGroup, major, folded);
  }

  final int separator = cleaned.indexOf(' of ');
  if (separator > 0) {
    final int? rank =
        _rankIndex[cleaned.substring(0, separator).toLowerCase()];
    final int? suit =
        _suitIndex[cleaned.substring(separator + 4).toLowerCase()];
    if (rank != null && suit != null) {
      return DeckPosition(_minorGroupOffset + suit, rank, folded);
    }
  }

  return DeckPosition(_unknownGroup, 0, folded);
}
