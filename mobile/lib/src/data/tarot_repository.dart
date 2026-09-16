import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/tarot_card.dart';
import 'embedding_index.dart';

/// The five deck sections, in traditional order. `typeEn`/`typeVi` are the
/// values the crawler writes into each card's `type` field.
class SuitDefinition {
  const SuitDefinition({
    required this.key,
    required this.typeEn,
    required this.typeVi,
    required this.labelEn,
    required this.labelVi,
    required this.emoji,
  });

  final String key;
  final String typeEn;
  final String typeVi;
  final String labelEn;
  final String labelVi;
  final String emoji;

  String typeFor(String language) => language == 'vi' ? typeVi : typeEn;

  String labelFor(String language) => language == 'vi' ? labelVi : labelEn;
}

const List<SuitDefinition> suitDefinitions = <SuitDefinition>[
  SuitDefinition(
    key: 'major',
    typeEn: 'Major Arcana',
    typeVi: 'Bộ Ẩn Chính',
    labelEn: 'Major Arcana',
    labelVi: 'Ẩn Chính',
    emoji: '🃏',
  ),
  SuitDefinition(
    key: 'wands',
    typeEn: 'Wands',
    typeVi: 'Gậy',
    labelEn: 'Wands',
    labelVi: 'Gậy',
    emoji: '🪄',
  ),
  SuitDefinition(
    key: 'cups',
    typeEn: 'Cups',
    typeVi: 'Cốc',
    labelEn: 'Cups',
    labelVi: 'Cốc',
    emoji: '🥤',
  ),
  SuitDefinition(
    key: 'swords',
    typeEn: 'Swords',
    typeVi: 'Kiếm',
    labelEn: 'Swords',
    labelVi: 'Kiếm',
    emoji: '🗡️',
  ),
  SuitDefinition(
    key: 'pentacles',
    typeEn: 'Pentacles',
    typeVi: 'Tiền Vàng',
    labelEn: 'Pentacles',
    labelVi: 'Tiền Vàng',
    emoji: '🪙',
  ),
];

/// Loads bundled cards and embedding indexes, caching one entry per language.
class TarotRepository {
  final Map<String, List<TarotCard>> _cards = <String, List<TarotCard>>{};
  final Map<String, EmbeddingIndex> _indexes = <String, EmbeddingIndex>{};

  Future<List<TarotCard>> cards(String language) async {
    final List<TarotCard>? cached = _cards[language];
    if (cached != null) {
      return cached;
    }

    final String raw =
        await rootBundle.loadString('assets/data/cards_$language.json');
    final List<TarotCard> parsed = <TarotCard>[
      for (final dynamic item in jsonDecode(raw) as List<dynamic>)
        TarotCard.fromJson(item as Map<String, dynamic>),
    ]..sort((TarotCard a, TarotCard b) =>
        a.deckPosition.compareTo(b.deckPosition));

    _cards[language] = parsed;
    return parsed;
  }

  Future<EmbeddingIndex> index(String language) async {
    final EmbeddingIndex? cached = _indexes[language];
    if (cached != null) {
      return cached;
    }
    final EmbeddingIndex loaded = await EmbeddingIndex.load(language);
    _indexes[language] = loaded;
    return loaded;
  }

  Future<List<TarotCard>> cardsForSuit(
    String language,
    SuitDefinition suit,
  ) async {
    final String expected = suit.typeFor(language);
    final List<TarotCard> all = await cards(language);
    return all
        .where((TarotCard card) => card.type == expected)
        .toList(growable: false);
  }

  Future<TarotCard?> findByName(String language, String query) async {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final TarotCard card in await cards(language)) {
      if (card.name.toLowerCase() == normalized) {
        return card;
      }
    }
    return null;
  }
}
