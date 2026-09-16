import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_draw.dart';
import '../models/tarot_card.dart';

/// Card rotation and question selection, ported from `learning/study.py`.
///
/// The deck walks a 78-card cycle: a card is never repeated until the whole
/// deck has been drawn, then a new shuffled cycle starts. The facet cursor
/// advances independently so consecutive draws ask about different aspects.
class StudyService {
  StudyService(this._prefs);

  static const String _stateKey = 'study_state_v1';
  static const String _openDrawKey = 'study_open_draw_v1';

  final SharedPreferences _prefs;
  final Random _random = Random();

  static const List<String> facetOrder = <String>[
    'overview',
    'upright.summary',
    'reversed.summary',
    'upright.love',
    'reversed.love',
    'upright.career',
    'reversed.career',
    'upright.finances',
    'reversed.finances',
    'upright.feelings',
    'reversed.feelings',
    'upright.actions',
    'reversed.actions',
    'symbols',
    'correspondences',
  ];

  static const Map<String, Map<String, String>> facetLabels =
      <String, Map<String, String>>{
    'overview': <String, String>{
      'en': 'overall card meaning',
      'vi': 'ý nghĩa tổng quan của lá bài',
    },
    'correspondences': <String, String>{
      'en': 'element, astrology, and yes/no correspondences',
      'vi': 'nguyên tố, chiêm tinh và yes/no',
    },
    'symbols': <String, String>{
      'en': 'main symbols',
      'vi': 'các biểu tượng chính',
    },
    'upright.summary': <String, String>{
      'en': 'upright meaning',
      'vi': 'ý nghĩa xuôi chiều',
    },
    'upright.love': <String, String>{
      'en': 'upright love meaning',
      'vi': 'ý nghĩa tình yêu khi xuôi chiều',
    },
    'upright.career': <String, String>{
      'en': 'upright career meaning',
      'vi': 'ý nghĩa sự nghiệp khi xuôi chiều',
    },
    'upright.finances': <String, String>{
      'en': 'upright finances meaning',
      'vi': 'ý nghĩa tài chính khi xuôi chiều',
    },
    'upright.feelings': <String, String>{
      'en': 'upright feelings meaning',
      'vi': 'ý nghĩa cảm xúc khi xuôi chiều',
    },
    'upright.actions': <String, String>{
      'en': 'upright actions meaning',
      'vi': 'ý nghĩa hành động khi xuôi chiều',
    },
    'reversed.summary': <String, String>{
      'en': 'reversed meaning',
      'vi': 'ý nghĩa ngược chiều',
    },
    'reversed.love': <String, String>{
      'en': 'reversed love meaning',
      'vi': 'ý nghĩa tình yêu khi ngược chiều',
    },
    'reversed.career': <String, String>{
      'en': 'reversed career meaning',
      'vi': 'ý nghĩa sự nghiệp khi ngược chiều',
    },
    'reversed.finances': <String, String>{
      'en': 'reversed finances meaning',
      'vi': 'ý nghĩa tài chính khi ngược chiều',
    },
    'reversed.feelings': <String, String>{
      'en': 'reversed feelings meaning',
      'vi': 'ý nghĩa cảm xúc khi ngược chiều',
    },
    'reversed.actions': <String, String>{
      'en': 'reversed actions meaning',
      'vi': 'ý nghĩa hành động khi ngược chiều',
    },
  };

  static String labelFor(String facet, String language) {
    final Map<String, String> entry =
        facetLabels[facet] ?? facetLabels['overview']!;
    return entry[language] ?? entry['en']!;
  }

  StudyDraw? get openDraw {
    final String? raw = _prefs.getString(_openDrawKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return StudyDraw.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> clearOpenDraw() => _prefs.remove(_openDrawKey);

  /// [deckSize] is how many cards a fresh cycle holds. Before the first draw
  /// the stored cycle is empty, which means "not started yet" rather than
  /// "nothing left", so the full deck is reported.
  StudyProgress progress(String language, {required int deckSize}) {
    final Map<String, dynamic> state = _state(language);
    final int remaining = (state['remaining'] as List<dynamic>).length;
    final int seen = (state['seen'] as List<dynamic>).length;
    return StudyProgress(
      cycle: state['cycle'] as int,
      remaining: remaining == 0 && seen == 0 ? deckSize : remaining,
      seen: seen,
    );
  }

  Future<StudyDraw> draw({
    required String language,
    required List<TarotCard> cards,
  }) async {
    final Map<String, dynamic> state = _state(language);
    final Map<String, TarotCard> byName = <String, TarotCard>{
      for (final TarotCard card in cards) card.name: card,
    };

    // Drop names that no longer exist in the bundled data before deciding
    // whether the cycle is exhausted.
    List<String> remaining = (state['remaining'] as List<dynamic>)
        .cast<String>()
        .where(byName.containsKey)
        .toList();
    List<String> seen =
        (state['seen'] as List<dynamic>).cast<String>().toList();

    if (remaining.isEmpty) {
      if (seen.isNotEmpty) {
        state['cycle'] = (state['cycle'] as int) + 1;
      }
      remaining = byName.keys.toList()..shuffle(_random);
      seen = <String>[];
    }

    final String cardName = remaining.removeAt(0);
    final TarotCard card = byName[cardName]!;
    seen.add(cardName);

    final String facet = _chooseFacet(card, state);
    state['remaining'] = remaining;
    state['seen'] = seen;

    final StudyDraw draw = StudyDraw(
      cardName: cardName,
      imageFile: card.imageFile,
      facet: facet,
      facetLabel: labelFor(facet, language),
      question: buildQuestion(cardName, facet, language),
      hint: buildHint(facet, language),
      cycle: state['cycle'] as int,
      remainingInCycle: remaining.length,
      language: language,
      createdAt: DateTime.now(),
    );

    await _prefs.setString('$_stateKey.$language', jsonEncode(state));
    await _prefs.setString(_openDrawKey, jsonEncode(draw.toJson()));
    return draw;
  }

  Map<String, dynamic> _state(String language) {
    final String? raw = _prefs.getString('$_stateKey.$language');
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed =
            jsonDecode(raw) as Map<String, dynamic>;
        parsed.putIfAbsent('cycle', () => 1);
        parsed.putIfAbsent('remaining', () => <dynamic>[]);
        parsed.putIfAbsent('seen', () => <dynamic>[]);
        parsed.putIfAbsent('facet_cursor', () => 0);
        return parsed;
      } on FormatException {
        // Fall through to a fresh cycle.
      }
    }
    return <String, dynamic>{
      'cycle': 1,
      'remaining': <dynamic>[],
      'seen': <dynamic>[],
      'facet_cursor': 0,
    };
  }

  String _chooseFacet(TarotCard card, Map<String, dynamic> state) {
    final List<String> available = availableFacets(card);
    if (available.isEmpty) {
      return 'overview';
    }

    final int cursor = state['facet_cursor'] as int;
    for (int offset = 0; offset < facetOrder.length; offset++) {
      final String candidate =
          facetOrder[(cursor + offset) % facetOrder.length];
      if (available.contains(candidate)) {
        state['facet_cursor'] = cursor + offset + 1;
        return candidate;
      }
    }

    state['facet_cursor'] = cursor + 1;
    return available.first;
  }

  static List<String> availableFacets(TarotCard card) =>
      facetOrder.where((String facet) => _hasValue(card, facet)).toList();

  static bool _hasValue(TarotCard card, String facet) {
    switch (facet) {
      case 'overview':
        return card.description.isNotEmpty || card.uprightKeywords.isNotEmpty;
      case 'correspondences':
        return card.type.isNotEmpty ||
            card.element.isNotEmpty ||
            card.astrology.isNotEmpty ||
            card.yesNo.isNotEmpty;
      case 'symbols':
        return card.symbols.isNotEmpty;
    }

    final List<String> parts = facet.split('.');
    final CardSection section =
        parts.first == 'upright' ? card.upright : card.reversed;
    if (parts[1] == 'summary') {
      return section.description.isNotEmpty;
    }
    return section.field(parts[1]).isNotEmpty;
  }

  static String buildQuestion(String cardName, String facet, String language) {
    final String label = labelFor(facet, language);
    if (language == 'vi') {
      return 'Lá bài: $cardName. Hãy giải thích $label. '
          'Trả lời 3-5 ý chính, có ví dụ ngắn nếu nhớ được.';
    }
    return 'Card: $cardName. Explain the $label. '
        'Answer with 3-5 key points and a short example if you can.';
  }

  static String buildHint(String facet, String language) {
    final List<String> parts = facet.split('.');
    if (parts.length == 2) {
      final bool reversed = parts.first == 'reversed';
      if (language == 'vi') {
        final String field = const <String, String>{
              'love': 'tình yêu',
              'career': 'sự nghiệp',
              'finances': 'tài chính',
              'feelings': 'cảm xúc',
              'actions': 'hành động',
            }[parts[1]] ??
            'ý nghĩa';
        if (reversed) {
          return 'Với $field, nhìn mặt ngược: điều gì đang bị kẹt, '
              'lệch nhịp hoặc cần điều chỉnh?';
        }
        return 'Với $field, nhìn mặt xuôi: năng lượng này hỗ trợ điều gì '
            'và nên ứng xử ra sao?';
      }

      final String field = const <String, String>{
            'love': 'love',
            'career': 'career',
            'finances': 'finances',
            'feelings': 'feelings',
            'actions': 'actions',
          }[parts[1]] ??
          'meaning';
      if (reversed) {
        return 'For $field, read the reversed side: what is blocked, '
            'distorted, or asking for adjustment?';
      }
      return 'For $field, read the upright side: what does this energy '
          'support, and what response fits?';
    }

    const Map<String, Map<String, String>> hints =
        <String, Map<String, String>>{
      'overview': <String, String>{
        'vi': 'Nêu năng lượng cốt lõi, tình huống thường gặp và một lời khuyên.',
        'en': 'Name the core energy, a common situation, and one practical '
            'advice.',
      },
      'correspondences': <String, String>{
        'vi': 'Liên hệ bộ bài, nguyên tố, chiêm tinh hoặc yes/no với cách lá '
            'vận hành.',
        'en': 'Connect suit, element, astrology, or yes/no to how the card '
            'behaves.',
      },
      'symbols': <String, String>{
        'vi': 'Chọn 1-2 biểu tượng nổi bật và giải thích chúng gợi điều gì.',
        'en': 'Pick 1-2 strong symbols and explain what they suggest.',
      },
    };

    final Map<String, String> entry = hints[facet] ?? hints['overview']!;
    return entry[language] ?? entry['en']!;
  }
}

class StudyProgress {
  const StudyProgress({
    required this.cycle,
    required this.remaining,
    required this.seen,
  });

  final int cycle;
  final int remaining;
  final int seen;
}
