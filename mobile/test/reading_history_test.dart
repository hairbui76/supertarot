import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supertarot_mobile/src/data/reading_history.dart';
import 'package:supertarot_mobile/src/data/tarot_repository.dart';
import 'package:supertarot_mobile/src/models/reference_chunk.dart';
import 'package:supertarot_mobile/src/models/tarot_card.dart';
import 'package:supertarot_mobile/src/services/qa_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TarotRepository repository;
  late List<TarotCard> cards;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = TarotRepository();
    cards = await repository.cards('vi');
  });

  Future<ReadingHistory> fresh() async =>
      ReadingHistory(await SharedPreferences.getInstance());

  test('round-trips a reading with picks in order and orientation', () async {
    final ReadingHistory history = await fresh();
    await history.add(
      QaResult(
        query: 'Công việc?',
        answer: '**1. The World** ...',
        mode: 'anthropic',
        spreadId: 'you_them_relationship',
        picks: <CardPick>[
          CardPick(cards[21], CardOrientation.reversed),
          CardPick(cards[0], CardOrientation.upright),
        ],
      ),
      'vi',
    );

    // A new instance reads only what was persisted.
    final List<SavedReading> saved = await (await fresh()).load(repository);
    expect(saved, hasLength(1));
    final QaResult result = saved.single.result;
    expect(saved.single.language, 'vi');
    expect(result.query, 'Công việc?');
    expect(result.answer, '**1. The World** ...');
    expect(result.mode, 'anthropic');
    expect(result.spreadId, 'you_them_relationship');
    expect(result.picks.map((CardPick p) => p.card.name),
        <String>['The World', 'The Fool']);
    expect(result.picks.map((CardPick p) => p.isReversed), <bool>[true, false]);
  });

  test('keeps chunk card names for plain questions', () async {
    final ReadingHistory history = await fresh();
    await history.add(
      const QaResult(
        query: 'Ace of Cups?',
        answer: 'answer',
        mode: 'context',
        chunks: <ReferenceChunk>[
          ReferenceChunk(
            id: 'x',
            cardName: 'Ace of Cups',
            orientation: null,
            facet: 'overview',
            title: '',
            text: 'long text',
            score: 0.5,
          ),
        ],
      ),
      'en',
    );
    final SavedReading saved = (await history.load(repository)).single;
    expect(saved.result.chunks.single.cardName, 'Ace of Cups');
    expect(saved.result.picks, isEmpty);
    expect(saved.result.spreadId, isNull);
  });

  test('newest first, capped, removable and clearable', () async {
    final ReadingHistory history = await fresh();
    for (int i = 0; i < ReadingHistory.maxEntries + 5; i++) {
      await history.add(
        QaResult(query: 'q$i', answer: 'a', mode: 'context'),
        'en',
      );
    }
    List<SavedReading> saved = await history.load(repository);
    expect(saved, hasLength(ReadingHistory.maxEntries));
    expect(saved.first.result.query, 'q${ReadingHistory.maxEntries + 4}');

    await history.remove(saved.first.id);
    saved = await history.load(repository);
    expect(saved, hasLength(ReadingHistory.maxEntries - 1));
    expect(saved.first.result.query, 'q${ReadingHistory.maxEntries + 3}');

    await history.clear();
    expect(await history.load(repository), isEmpty);
  });

  test('corrupt storage reads as empty instead of throwing', () async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'qa_history_v1': '{not json'});
    expect(await (await fresh()).load(repository), isEmpty);
  });
}
