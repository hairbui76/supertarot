import 'deck_order.dart';

/// One tarot card as exported from `data/output/tarot_meanings*.json`.
class TarotCard {
  TarotCard({
    required this.name,
    required this.type,
    required this.element,
    required this.astrology,
    required this.yesNo,
    required this.description,
    required this.imageFile,
    required this.uprightKeywords,
    required this.reversedKeywords,
    required this.upright,
    required this.reversed,
    required this.symbols,
    required this.shortMeaning,
    required this.shortReversedMeaning,
  });

  factory TarotCard.fromJson(Map<String, dynamic> json) {
    return TarotCard(
      name: _text(json['name']),
      type: _text(json['type']),
      element: _text(json['element']),
      astrology: _text(json['astrology']),
      yesNo: _text(json['yes_no']),
      description: _text(json['description']),
      imageFile: _text(json['card_image']),
      uprightKeywords: _stringList(json['upright_keywords']),
      reversedKeywords: _stringList(json['reversed_keywords']),
      upright: CardSection.fromJson(json['upright']),
      reversed: CardSection.fromJson(json['reversed']),
      symbols: <CardSymbol>[
        for (final dynamic item in (json['symbols'] as List<dynamic>? ?? const <dynamic>[]))
          CardSymbol.fromJson(item as Map<String, dynamic>),
      ],
      shortMeaning: _text(json['short_meaning']),
      shortReversedMeaning: _text(json['short_rev_meaning']),
    );
  }

  final String name;
  final String type;
  final String element;
  final String astrology;
  final String yesNo;
  final String description;
  final String imageFile;
  final List<String> uprightKeywords;
  final List<String> reversedKeywords;
  final CardSection upright;
  final CardSection reversed;
  final List<CardSymbol> symbols;
  final String shortMeaning;
  final String shortReversedMeaning;

  String get assetPath => 'assets/images/$imageFile';

  DeckPosition get deckPosition => deckPositionOf(name);

  CardSection section(CardOrientation orientation) =>
      orientation == CardOrientation.upright ? upright : reversed;

  List<String> keywords(CardOrientation orientation) =>
      orientation == CardOrientation.upright ? uprightKeywords : reversedKeywords;

  String shortSummary(CardOrientation orientation) =>
      orientation == CardOrientation.upright ? shortMeaning : shortReversedMeaning;
}

enum CardOrientation { upright, reversed }

extension CardOrientationKey on CardOrientation {
  String get key => this == CardOrientation.upright ? 'upright' : 'reversed';
}

/// The upright or reversed half of a card.
class CardSection {
  const CardSection({
    required this.description,
    required this.love,
    required this.career,
    required this.finances,
    required this.feelings,
    required this.actions,
  });

  factory CardSection.fromJson(dynamic json) {
    final Map<String, dynamic> map =
        (json as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return CardSection(
      description: _text(map['description']),
      love: _text(map['love']),
      career: _text(map['career']),
      finances: _text(map['finances']),
      feelings: _text(map['feelings']),
      actions: _text(map['actions']),
    );
  }

  final String description;
  final String love;
  final String career;
  final String finances;
  final String feelings;
  final String actions;

  String field(String name) {
    switch (name) {
      case 'love':
        return love;
      case 'career':
        return career;
      case 'finances':
        return finances;
      case 'feelings':
        return feelings;
      case 'actions':
        return actions;
      default:
        return description;
    }
  }

  bool get isEmpty =>
      description.isEmpty &&
      love.isEmpty &&
      career.isEmpty &&
      finances.isEmpty &&
      feelings.isEmpty &&
      actions.isEmpty;
}

class CardSymbol {
  const CardSymbol({required this.name, required this.meaning});

  factory CardSymbol.fromJson(Map<String, dynamic> json) => CardSymbol(
        name: _text(json['name']),
        meaning: _text(json['meaning']),
      );

  final String name;
  final String meaning;
}

String _text(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is List) {
    return value.map(_text).where((String item) => item.isNotEmpty).join(', ');
  }
  return value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map(_text)
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final String text = _text(value);
  if (text.isEmpty) {
    return const <String>[];
  }
  return text.split(',').map((String item) => item.trim()).toList();
}
