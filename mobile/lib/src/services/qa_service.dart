import '../data/embedding_index.dart';
import '../data/settings_store.dart';
import '../data/tarot_repository.dart';
import '../models/reference_chunk.dart';
import 'llm_client.dart';

/// Outcome of a freeform question: the answer text plus what it was built from.
class QaResult {
  const QaResult({
    required this.query,
    required this.answer,
    required this.chunks,
    required this.mode,
    this.error,
  });

  final String query;
  final String answer;
  final List<ReferenceChunk> chunks;

  /// Which provider produced the answer, or `context` when the app fell back
  /// to showing retrieved reference text without LLM synthesis.
  final String mode;
  final String? error;
}

/// Freeform tarot Q&A over the bundled embedding index, ported from
/// `app/qa.py`. Retrieval is fully offline; only the synthesis step needs a
/// provider key.
class QaService {
  QaService({required this.repository, required this.client});

  final TarotRepository repository;
  final LlmClient client;

  Future<QaResult> ask({
    required SettingsStore settings,
    required String query,
  }) async {
    final String language = settings.language;
    final EmbeddingIndex index = await repository.index(language);
    final List<ReferenceChunk> chunks =
        index.search(query, topK: settings.qaTopK);

    final LlmProvider? provider = settings.resolveProvider(settings.qaProvider);
    if (provider == null) {
      return QaResult(
        query: query,
        answer: _contextAnswer(chunks, language, null),
        chunks: chunks,
        mode: 'context',
      );
    }

    try {
      final String raw = await client.complete(
        provider: provider,
        model: settings.model(provider),
        apiKey: settings.apiKey(provider),
        systemPrompt: _systemPrompt(language),
        userPrompt: _userPrompt(query, chunks, language),
        temperature: 0.2,
      );
      return QaResult(
        query: query,
        answer: cleanAnswer(raw),
        chunks: chunks,
        mode: provider.id,
      );
    } on LlmException catch (error) {
      return QaResult(
        query: query,
        answer: _contextAnswer(chunks, language, error.message),
        chunks: chunks,
        mode: 'context',
        error: error.message,
      );
    }
  }

  static String _systemPrompt(String language) {
    if (language == 'vi') {
      return 'Bạn là SuperTarot, trợ lý học tarot. '
          'Trả lời bằng tiếng Việt tự nhiên, ưu tiên câu hỏi tarot. '
          'Xâu chuỗi các mảnh dữ liệu được retrieve từ embedding index: '
          'nghĩa xuôi/ngược, tình yêu, sự nghiệp, tài chính, cảm xúc, '
          'hành động, biểu tượng, nguyên tố, chiêm tinh và yes/no nếu liên quan. '
          'Không bịa chi tiết trái với dữ liệu. Không thêm mục Lưu ý, '
          'không thêm mục Tham chiếu/Nguồn ở cuối, và không nhắc tới chunk, '
          'embedding hay tài liệu tham chiếu. Dùng **...** khi cần in đậm '
          'và dùng ký tự • cho danh sách.';
    }
    return 'You are SuperTarot, a tarot study assistant. '
        'Answer in natural English and prioritize tarot questions. '
        'Synthesize retrieved tarot data chunks from the embedding index: '
        'upright/reversed meanings, love, career, finances, feelings, actions, '
        'symbols, elements, astrology, and yes/no where relevant. '
        'Do not invent details that contradict the data. Do not add Note, '
        'References, or Sources sections, and do not mention chunks, '
        'embeddings, or reference material. Use **...** for emphasis and • '
        'for bullets.';
  }

  static String _userPrompt(
    String query,
    List<ReferenceChunk> chunks,
    String language,
  ) {
    final String references = _formatReferences(chunks);
    if (language == 'vi') {
      return 'Câu hỏi người dùng:\n$query\n\n'
          'Dữ liệu tarot đã retrieve:\n$references\n\n'
          'Hãy trả lời 4-8 câu hoặc vài gạch đầu dòng ngắn. '
          'Nếu có nhiều lá bài liên quan, hãy so sánh và kết nối chúng. '
          'Không thêm dòng Lưu ý, Tham chiếu hoặc Nguồn.';
    }
    return 'User question:\n$query\n\n'
        'Retrieved tarot data:\n$references\n\n'
        'Answer in 4-8 sentences or a few short bullets. '
        'If several cards are relevant, compare and connect them. '
        'Do not add Note, References, or Sources lines.';
  }

  static String _formatReferences(List<ReferenceChunk> chunks) {
    final List<String> blocks = <String>[];
    for (int i = 0; i < chunks.length; i++) {
      final ReferenceChunk chunk = chunks[i];
      blocks.add('[${i + 1}] ${chunk.label}\n'
          'score=${chunk.score.toStringAsFixed(4)}\n'
          '${chunk.text}');
    }
    return blocks.join('\n\n');
  }

  static String _contextAnswer(
    List<ReferenceChunk> chunks,
    String language,
    String? error,
  ) {
    if (chunks.isEmpty) {
      return language == 'vi'
          ? 'Mình chưa tìm thấy mảnh tham chiếu phù hợp trong dữ liệu tarot. '
              'Bạn có thể hỏi rõ tên lá bài, lĩnh vực như tình yêu/sự nghiệp, '
              'hoặc yếu tố chiêm tinh/nguyên tố muốn liên hệ.'
          : 'I could not find matching tarot references. Ask with a card name, '
              'a facet such as love/career, or an astrology/element angle.';
    }

    final List<String> lines = <String>[];
    if (language == 'vi') {
      lines.add(error == null
          ? 'Chưa có API key nên mình trả về dữ liệu gốc liên quan nhất. '
              'Thêm key ở tab Cài đặt để có phần diễn giải tổng hợp.'
          : 'Mình tìm được dữ liệu liên quan nhưng phần tổng hợp bằng LLM đang '
              'lỗi, nên tạm trả về nội dung gần nhất.\nLỗi: $error');
      lines.addAll(<String>['', 'Gợi ý đọc nhanh:']);
    } else {
      lines.add(error == null
          ? 'No API key is set, so here is the closest source material. '
              'Add a key in Settings for a synthesized answer.'
          : 'I found related tarot data, but LLM synthesis failed, so here is '
              'the closest content instead.\nError: $error');
      lines.addAll(<String>['', 'Quick notes:']);
    }

    for (final ReferenceChunk chunk in chunks.take(4)) {
      lines.add('• **${chunk.cardName} - ${chunk.facet}**: '
          '${_compact(chunk.text, 320)}');
    }
    return lines.join('\n');
  }

  /// Strips the trailing "References"/"Note" blocks some models add despite
  /// the system prompt, mirroring `clean_answer_text()` in `app/qa.py`.
  static String cleanAnswer(String answer) {
    String text = answer.replaceAll(
      RegExp(
        r'\n+\s*(?:\*\*)?\s*(?:Tham chiếu|References|Nguồn|Sources)'
        r'\s*(?:\*\*)?\s*:\s*[\s\S]*$',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\n?\s*[*_]*\(\s*(?:Lưu ý|Note)\s*:[\s\S]*?\)\s*[*_]*',
          caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'^\s*[*_()]*\s*(?:Lưu ý|Note)\s*:.*$',
          caseSensitive: false, multiLine: true),
      '',
    );

    final RegExp mention = RegExp(
      r'(tài liệu tham chiếu|reference material|embedding reference)',
      caseSensitive: false,
    );
    return text
        .split('\n')
        .where((String line) => !mention.hasMatch(line))
        .map((String line) => line.trimRight())
        .join('\n')
        .trim();
  }

  static String _compact(String value, int limit) {
    final String collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= limit
        ? collapsed
        : '${collapsed.substring(0, limit - 1).trimRight()}…';
  }
}
