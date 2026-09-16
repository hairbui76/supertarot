import 'dart:convert';

import '../data/embedding_index.dart';
import '../data/settings_store.dart';
import '../data/tarot_repository.dart';
import '../models/reference_chunk.dart';
import '../models/study_draw.dart';
import 'llm_client.dart';
import 'study_service.dart';

/// What came back from a grading attempt. `grade` is null when no provider is
/// configured or the call failed; `error` then says why.
class GradingOutcome {
  const GradingOutcome({
    required this.chunks,
    required this.mode,
    this.grade,
    this.error,
  });

  final List<ReferenceChunk> chunks;
  final String mode;
  final GradeResult? grade;
  final String? error;
}

/// Retrieval + rubric grading, ported from `learning/verification.py` and
/// `app/grading.py`.
class GradingService {
  GradingService({required this.repository, required this.client});

  final TarotRepository repository;
  final LlmClient client;

  Future<GradingOutcome> grade({
    required SettingsStore settings,
    required StudyDraw draw,
    required String answer,
  }) async {
    final String language = settings.language;
    final EmbeddingIndex index = await repository.index(language);
    final List<ReferenceChunk> chunks = _retrieve(
      index: index,
      cardName: draw.cardName,
      facet: draw.facet,
      language: language,
      topK: settings.answerTopK,
    );

    final LlmProvider? provider =
        settings.resolveProvider(settings.gradingProvider);
    if (provider == null) {
      return GradingOutcome(
        chunks: chunks,
        mode: 'prompt',
        error: language == 'vi'
            ? 'Chưa cấu hình API key nên chưa chấm tự động được. '
                'Thêm key ở tab Cài đặt.'
            : 'No API key is configured, so automatic grading is off. '
                'Add one in Settings.',
      );
    }

    try {
      final String raw = await client.complete(
        provider: provider,
        model: settings.model(provider),
        apiKey: settings.apiKey(provider),
        systemPrompt: 'Return valid JSON only. Do not wrap it in markdown.',
        userPrompt: buildPrompt(
          cardName: draw.cardName,
          facet: draw.facet,
          userAnswer: answer,
          chunks: chunks,
          language: language,
        ),
        temperature: 0,
        jsonMode: true,
      );
      return GradingOutcome(
        chunks: chunks,
        mode: provider.id,
        grade: GradeResult.fromJson(parseJsonObject(raw)),
      );
    } on LlmException catch (error) {
      return GradingOutcome(
        chunks: chunks,
        mode: provider.id,
        error: error.message,
      );
    } on FormatException catch (error) {
      return GradingOutcome(
        chunks: chunks,
        mode: provider.id,
        error: 'Could not parse the grader response as JSON: ${error.message}',
      );
    }
  }

  /// Narrow the search to the asked facet first; fall back to the whole card
  /// when that filter matches nothing.
  static List<ReferenceChunk> _retrieve({
    required EmbeddingIndex index,
    required String cardName,
    required String facet,
    required String language,
    required int topK,
  }) {
    String? orientation;
    String? indexFacet = facet;
    if (facet.contains('.')) {
      final List<String> parts = facet.split('.');
      orientation = parts.first;
      indexFacet = parts[1] == 'summary' ? 'summary' : parts[1];
    }

    final String query =
        '$cardName ${StudyService.labelFor(facet, language)}';
    final List<ReferenceChunk> filtered = index.search(
      query,
      topK: topK,
      cardName: cardName,
      orientation: orientation,
      facet: indexFacet,
    );
    if (filtered.isNotEmpty) {
      return filtered;
    }
    return index.search(query, topK: topK, cardName: cardName);
  }

  static String buildPrompt({
    required String cardName,
    required String facet,
    required String userAnswer,
    required List<ReferenceChunk> chunks,
    required String language,
  }) {
    final List<String> blocks = <String>[];
    for (int i = 0; i < chunks.length; i++) {
      final ReferenceChunk chunk = chunks[i];
      blocks.add('[${i + 1}] ${chunk.title}\n'
          'score=${chunk.score.toStringAsFixed(4)}\n'
          '${chunk.text}');
    }
    final String references = blocks.join('\n\n');
    final String label = StudyService.labelFor(facet, language);

    const String schema = '{\n'
        '  "score": 0,\n'
        '  "passed": false,\n'
        '  "correct_points": [],\n'
        '  "missing_points": [],\n'
        '  "incorrect_points": [],\n'
        '  "feedback": "",\n'
        '  "next_hint": ""\n'
        '}';

    if (language == 'vi') {
      return 'Bạn là bot học tarot. Hãy chấm câu trả lời của người học dựa '
          'trên tài liệu tham chiếu.\n\n'
          'Lá bài: $cardName\n'
          'Mục hỏi: $label\n\n'
          'Câu trả lời của người học:\n$userAnswer\n\n'
          'Tài liệu tham chiếu đã retrieve bằng embedding:\n$references\n\n'
          'Quy tắc chấm:\n'
          '- Không yêu cầu đúng từng chữ; chấp nhận diễn giải tương đương.\n'
          '- Ưu tiên các ý nghĩa cốt lõi của đúng lá bài và đúng mục hỏi.\n'
          '- Nếu người học nói đúng nhưng thiếu ý, ghi rõ ý còn thiếu.\n'
          '- Nếu người học trộn sang lá khác, hướng khác, hoặc bịa ý trái '
          'nghĩa, ghi rõ.\n'
          '- Trả về JSON thuần túy, không markdown.\n\n'
          'Schema:\n$schema';
    }

    return 'You are a tarot study bot. Grade the learner answer against the '
        'retrieved reference material.\n\n'
        'Card: $cardName\n'
        'Asked facet: $label\n\n'
        'Learner answer:\n$userAnswer\n\n'
        'Embedding-retrieved reference material:\n$references\n\n'
        'Grading rules:\n'
        '- Do not require exact wording; accept equivalent phrasing.\n'
        '- Prioritize core meanings for the correct card and asked facet.\n'
        '- If the learner is correct but incomplete, name the missing ideas.\n'
        '- If the learner mixes in another card, another orientation, or a '
        'contradictory idea, name it.\n'
        '- Return plain JSON only, no markdown.\n\n'
        'Schema:\n$schema';
  }

  /// Models occasionally wrap JSON in a markdown fence or add prose around it.
  static Map<String, dynamic> parseJsonObject(String text) {
    String cleaned = text.trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } on FormatException {
      final int start = cleaned.indexOf('{');
      final int end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return jsonDecode(cleaned.substring(start, end + 1))
            as Map<String, dynamic>;
      }
      rethrow;
    }
  }
}
