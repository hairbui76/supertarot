import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reference_chunk.dart';
import '../models/tarot_card.dart';
import '../services/qa_service.dart';
import 'tarot_repository.dart';

/// One answer from the Ask tab, kept on device.
class SavedReading {
  const SavedReading({
    required this.id,
    required this.createdAt,
    required this.language,
    required this.result,
  });

  final String id;
  final DateTime createdAt;
  final String language;
  final QaResult result;
}

/// Ask-tab history in SharedPreferences, newest first.
///
/// Cards are stored by name and orientation only, then resolved against the
/// bundled data on load, so a data refresh never leaves stale card text in
/// storage. Retrieved chunks keep just their card names, which is all the
/// screen shows of them.
class ReadingHistory {
  ReadingHistory(this._prefs);

  static const String _key = 'qa_history_v1';

  /// Enough to scroll back through weeks of readings without the JSON blob
  /// growing past a few hundred KB.
  static const int maxEntries = 100;

  final SharedPreferences _prefs;
  final Random _random = Random();

  Future<List<SavedReading>> load(TarotRepository repository) async {
    final List<Map<String, dynamic>> raw = _readRaw();
    final Map<String, Map<String, TarotCard>> byLanguage =
        <String, Map<String, TarotCard>>{};
    final List<SavedReading> readings = <SavedReading>[];

    for (final Map<String, dynamic> entry in raw) {
      final String language = entry['language'] as String? ?? 'vi';
      final Map<String, TarotCard> cards =
          byLanguage[language] ??= <String, TarotCard>{
        for (final TarotCard card in await repository.cards(language))
          card.name: card,
      };

      final List<CardPick> picks = <CardPick>[];
      for (final dynamic item in entry['picks'] as List<dynamic>? ?? const []) {
        final Map<String, dynamic> pick = item as Map<String, dynamic>;
        final TarotCard? card = cards[pick['name']];
        if (card != null) {
          picks.add(CardPick(
            card,
            pick['reversed'] == true
                ? CardOrientation.reversed
                : CardOrientation.upright,
          ));
        }
      }

      readings.add(SavedReading(
        id: entry['id'] as String,
        createdAt: DateTime.tryParse(entry['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        language: language,
        result: QaResult(
          query: entry['query'] as String? ?? '',
          answer: entry['answer'] as String? ?? '',
          mode: entry['mode'] as String? ?? 'context',
          error: entry['error'] as String?,
          picks: picks,
          spreadId: entry['spread'] as String?,
          chunks: <ReferenceChunk>[
            for (final dynamic name
                in entry['chunk_cards'] as List<dynamic>? ?? const [])
              ReferenceChunk(
                id: '',
                cardName: name as String,
                orientation: null,
                facet: '',
                title: '',
                text: '',
                score: 0,
              ),
          ],
        ),
      ));
    }
    return readings;
  }

  Future<SavedReading> add(QaResult result, String language) async {
    final DateTime now = DateTime.now();
    final SavedReading reading = SavedReading(
      // Clock ticks can repeat on fast successive saves; the suffix keeps ids
      // unique so remove() never takes out a neighbour.
      id: '${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(16)}',
      createdAt: now,
      language: language,
      result: result,
    );

    final List<Map<String, dynamic>> raw = _readRaw()
      ..insert(0, <String, dynamic>{
        'id': reading.id,
        'created_at': now.toIso8601String(),
        'language': language,
        'query': result.query,
        'answer': result.answer,
        'mode': result.mode,
        if (result.error != null) 'error': result.error,
        if (result.spreadId != null) 'spread': result.spreadId,
        'picks': <Map<String, dynamic>>[
          for (final CardPick pick in result.picks)
            <String, dynamic>{
              'name': pick.card.name,
              'reversed': pick.isReversed,
            },
        ],
        'chunk_cards': <String>[
          for (final ReferenceChunk chunk in result.chunks.take(5))
            chunk.cardName,
        ],
      });
    await _write(raw.take(maxEntries).toList());
    return reading;
  }

  Future<void> remove(String id) async {
    await _write(_readRaw()
        .where((Map<String, dynamic> entry) => entry['id'] != id)
        .toList());
  }

  Future<void> clear() => _prefs.remove(_key);

  List<Map<String, dynamic>> _readRaw() {
    final String? raw = _prefs.getString(_key);
    if (raw == null) {
      return <Map<String, dynamic>>[];
    }
    try {
      return <Map<String, dynamic>>[
        for (final dynamic item in jsonDecode(raw) as List<dynamic>)
          item as Map<String, dynamic>,
      ];
    } catch (_) {
      // Corrupt or foreign data: start over rather than break the tab.
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> entries) =>
      _prefs.setString(_key, jsonEncode(entries));
}
