import '../data/embedding_index.dart';
import '../data/settings_store.dart';
import '../data/tarot_repository.dart';
import '../models/reference_chunk.dart';
import '../models/spread.dart';
import '../models/tarot_card.dart';
import 'llm_client.dart';

/// One card the user laid out for a reading, in the orientation it fell.
class CardPick {
  const CardPick(this.card, this.orientation);

  final TarotCard card;
  final CardOrientation orientation;

  bool get isReversed => orientation == CardOrientation.reversed;

  CardPick flipped() => CardPick(
        card,
        isReversed ? CardOrientation.upright : CardOrientation.reversed,
      );
}

/// Outcome of a freeform question: the answer text plus what it was built from.
class QaResult {
  const QaResult({
    required this.query,
    required this.answer,
    required this.mode,
    this.chunks = const <ReferenceChunk>[],
    this.picks = const <CardPick>[],
    this.spreadId,
    this.error,
  });

  final String query;
  final String answer;
  final List<ReferenceChunk> chunks;

  /// Cards the answer reads, in order. Empty for a plain question.
  final List<CardPick> picks;

  /// [SpreadDefinition.id] the cards were laid in; null for a plain question.
  final String? spreadId;

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

  /// Reads [picks] in order against [question], card N sitting in position N
  /// of [spread]. Card text comes straight from the bundled data rather than
  /// retrieval, so every chosen card is covered in the orientation it fell.
  Future<QaResult> interpret({
    required SettingsStore settings,
    required String question,
    required List<CardPick> picks,
    SpreadDefinition? spread,
  }) async {
    final SpreadDefinition layout = spread ?? spreadById('free');
    final String language = settings.language;
    final LlmProvider? provider = settings.resolveProvider(settings.qaProvider);
    if (provider == null) {
      return QaResult(
        query: question,
        answer: _readingFallback(picks, layout, language, null),
        picks: picks,
        spreadId: layout.id,
        mode: 'context',
      );
    }

    try {
      final String raw = await client.complete(
        provider: provider,
        model: settings.model(provider),
        apiKey: settings.apiKey(provider),
        systemPrompt: _readingSystemPrompt(language),
        userPrompt:
            readingUserPrompt(question, picks, language, spread: layout),
        temperature: 0.4,
      );
      return QaResult(
        query: question,
        answer: cleanAnswer(raw),
        picks: picks,
        spreadId: layout.id,
        mode: provider.id,
      );
    } on LlmException catch (error) {
      return QaResult(
        query: question,
        answer: _readingFallback(picks, layout, language, error.message),
        picks: picks,
        spreadId: layout.id,
        mode: 'context',
        error: error.message,
      );
    }
  }

  static String _readingSystemPrompt(String language) {
    if (language == 'vi') {
      return 'Bạn là SuperTarot, người đọc bài tarot. Trả lời bằng tiếng Việt '
          'tự nhiên, ấm áp nhưng thẳng thắn. Người dùng đưa ra câu hỏi và các '
          'lá đã rút theo đúng thứ tự, mỗi lá xuôi hoặc ngược. Đọc từng lá theo '
          'đúng chiều của nó, theo ý nghĩa vị trí nếu có kiểu trải, gắn với câu '
          'hỏi, rồi kết nối các lá thành một '
          'mạch chung. Bám vào dữ liệu lá bài được cung cấp, không bịa nghĩa '
          'trái với dữ liệu. Không thêm mục Lưu ý, Tham chiếu hay Nguồn. Dùng '
          '**...** khi cần in đậm và ký tự • cho danh sách.';
    }
    return 'You are SuperTarot, a tarot reader. Answer in natural English, '
        'warm but direct. The user gives a question and the cards they drew, '
        'in order, each upright or reversed. Read each card in its own '
        'orientation and, when a spread is given, through its position, '
        'against the question, then connect the cards into one '
        'thread. Stay grounded in the card data provided and do not invent '
        'meanings that contradict it. Do not add Note, References, or Sources '
        'sections. Use **...** for emphasis and • for bullets.';
  }

  static String readingUserPrompt(
    String question,
    List<CardPick> picks,
    String language, {
    SpreadDefinition? spread,
  }) {
    final bool vi = language == 'vi';
    final SpreadDefinition? layout =
        spread == null || spread.isFree ? null : spread;
    final String asked = question.trim().isEmpty
        ? (vi
            ? '(Không có câu hỏi cụ thể - hãy đọc tổng quan.)'
            : '(No specific question - give a general reading.)')
        : question.trim();

    final String cards = <String>[
      for (int i = 0; i < picks.length; i++)
        _cardBlock(i + 1, picks[i], layout?.positionAt(i), language),
    ].join('\n\n');

    if (layout == null) {
      if (vi) {
        return 'Câu hỏi:\n$asked\n\n'
            'Các lá đã rút (${picks.length} lá, theo thứ tự):\n\n$cards\n\n'
            'Cách trả lời:\n'
            '• Mở đầu bằng 1-2 câu trả lời thẳng vào câu hỏi.\n'
            '• Với từng lá: dòng **N. Tên lá (Xuôi/Ngược)** rồi 2-4 câu giải '
            'nghĩa gắn với câu hỏi.\n'
            '• Nếu câu hỏi không nêu cách trải bài, đọc các lá như một dòng '
            'chảy theo thứ tự (ví dụ 3 lá: quá khứ → hiện tại → tương lai).\n'
            '• Kết thúc bằng phần tổng kết kết nối các lá và một lời khuyên cụ '
            'thể.';
      }
      return 'Question:\n$asked\n\n'
          'Cards drawn (${picks.length}, in order):\n\n$cards\n\n'
          'How to answer:\n'
          '• Open with 1-2 sentences that answer the question directly.\n'
          '• For each card: a line **N. Card name (Upright/Reversed)** then 2-4 '
          'sentences tying it to the question.\n'
          '• If the question names no spread, read the cards as a flow in '
          'order (e.g. 3 cards: past → present → future).\n'
          '• Close with a summary that connects the cards and one concrete '
          'piece of advice.';
    }

    final int total = layout.positions.length;
    final String positions = <String>[
      for (int i = 0; i < total; i++) _positionLine(i, layout, language),
    ].join('\n');
    final bool partial = picks.length < total;

    if (vi) {
      return 'Câu hỏi:\n$asked\n\n'
          'Kiểu trải: ${layout.nameVi}\n${layout.descriptionVi}\n'
          'Các vị trí:\n$positions\n\n'
          'Các lá đã rút (${picks.length}/$total lá, lá N nằm ở vị trí N):\n\n'
          '$cards\n\n'
          'Cách trả lời:\n'
          '• Mở đầu bằng 1-2 câu trả lời thẳng vào câu hỏi.\n'
          '• Với từng lá: dòng **N. Vị trí - Tên lá (Xuôi/Ngược)** rồi 2-4 câu '
          'đọc lá theo đúng ý nghĩa vị trí của nó và gắn với câu hỏi.\n'
          '${partial ? '• Người dùng chưa rút đủ lá; chỉ đọc các vị trí đã có lá, không đoán lá còn thiếu.\n' : ''}'
          '• Kết thúc bằng phần tổng kết kết nối các vị trí và một lời khuyên '
          'cụ thể.';
    }
    return 'Question:\n$asked\n\n'
        'Spread: ${layout.nameEn}\n${layout.descriptionEn}\n'
        'Positions:\n$positions\n\n'
        'Cards drawn (${picks.length}/$total, card N sits in position N):\n\n'
        '$cards\n\n'
        'How to answer:\n'
        '• Open with 1-2 sentences that answer the question directly.\n'
        '• For each card: a line **N. Position - Card name '
        '(Upright/Reversed)** then 2-4 sentences reading the card through its '
        'position and tying it to the question.\n'
        '${partial ? '• The spread is not complete; read only the positions that have a card and do not guess the missing ones.\n' : ''}'
        '• Close with a summary that connects the positions and one concrete '
        'piece of advice.';
  }

  static String _positionLine(
    int index,
    SpreadDefinition spread,
    String language,
  ) {
    final SpreadPosition position = spread.positions[index];
    final String hint = position.hint(language);
    return '${index + 1}. ${position.label(language)}'
        '${hint.isEmpty ? '' : ' ($hint)'}';
  }

  static String _orientationLabel(CardPick pick, bool vi) =>
      pick.isReversed ? (vi ? 'Ngược' : 'Reversed') : (vi ? 'Xuôi' : 'Upright');

  static String _cardBlock(
    int position,
    CardPick pick,
    SpreadPosition? slot,
    String language,
  ) {
    final bool vi = language == 'vi';
    final TarotCard card = pick.card;
    final CardSection section = card.section(pick.orientation);
    final String place = slot == null ? '' : '${slot.label(language)}: ';
    final List<String> lines = <String>[
      '[$position] $place${card.name} - ${_orientationLabel(pick, vi)}',
    ];

    void add(String label, String value) {
      if (value.trim().isNotEmpty) {
        lines.add('$label: ${value.trim()}');
      }
    }

    add(vi ? 'Bộ' : 'Suit', card.type);
    add(vi ? 'Nguyên tố' : 'Element', card.element);
    add(vi ? 'Chiêm tinh' : 'Astrology', card.astrology);
    add('Yes/No', card.yesNo);
    add(vi ? 'Từ khóa' : 'Keywords',
        card.keywords(pick.orientation).join(', '));
    add(vi ? 'Tóm tắt' : 'Summary', card.shortSummary(pick.orientation));
    add(vi ? 'Ý nghĩa' : 'Meaning', section.description);
    add(vi ? 'Tình yêu' : 'Love', section.love);
    add(vi ? 'Sự nghiệp' : 'Career', section.career);
    add(vi ? 'Tài chính' : 'Finances', section.finances);
    add(vi ? 'Cảm xúc' : 'Feelings', section.feelings);
    add(vi ? 'Hành động' : 'Actions', section.actions);
    return lines.join('\n');
  }

  static String _readingFallback(
    List<CardPick> picks,
    SpreadDefinition spread,
    String language,
    String? error,
  ) {
    final bool vi = language == 'vi';
    final List<String> lines = <String>[];
    if (vi) {
      lines.add(error == null
          ? 'Chưa có API key nên đây là nghĩa gốc của từng lá. Thêm key ở tab '
              'Cài đặt để AI giải bài theo câu hỏi.'
          : 'Phần giải bài bằng AI đang lỗi, tạm hiện nghĩa gốc của từng lá.'
              '\nLỗi: $error');
    } else {
      lines.add(error == null
          ? "No API key is set, so here is each card's base meaning. Add a key "
              'in Settings for a reading tied to your question.'
          : "The AI reading failed, so here is each card's base meaning."
              '\nError: $error');
    }
    lines.add('');

    for (int i = 0; i < picks.length; i++) {
      final CardPick pick = picks[i];
      final String short = pick.card.shortSummary(pick.orientation);
      final String summary = short.isNotEmpty
          ? short
          : pick.card.section(pick.orientation).description;
      final SpreadPosition? slot = spread.positionAt(i);
      final String place = slot == null ? '' : '${slot.label(language)} - ';
      lines.add('**${i + 1}. $place${pick.card.name} '
          '(${_orientationLabel(pick, vi)})**: ${_compact(summary, 360)}');
    }
    return lines.join('\n');
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
