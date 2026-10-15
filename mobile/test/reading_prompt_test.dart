import 'package:flutter_test/flutter_test.dart';
import 'package:supertarot_mobile/src/data/tarot_repository.dart';
import 'package:supertarot_mobile/src/models/spread.dart';
import 'package:supertarot_mobile/src/models/tarot_card.dart';
import 'package:supertarot_mobile/src/services/qa_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reading prompt keeps pick order and each card orientation', () async {
    final List<TarotCard> cards = await TarotRepository().cards('vi');
    final TarotCard fool = cards.first;
    final TarotCard world = cards[21];

    final String prompt = QaService.readingUserPrompt(
        'Công việc sắp tới?',
        <CardPick>[
          CardPick(world, CardOrientation.reversed),
          CardPick(fool, CardOrientation.upright),
        ],
        'vi');

    final int first = prompt.indexOf('[1] The World - Ngược');
    final int second = prompt.indexOf('[2] The Fool - Xuôi');
    expect(first, greaterThanOrEqualTo(0));
    expect(second, greaterThan(first));
    expect(prompt, contains('Công việc sắp tới?'));
    expect(prompt, contains(world.reversed.description));
    expect(prompt, contains(fool.upright.description));
    expect(prompt, isNot(contains(world.upright.description)));
  });

  test('spread prompt names each position and flags a partial layout',
      () async {
    final List<TarotCard> cards = await TarotRepository().cards('vi');
    final SpreadDefinition celtic = spreadById('celtic_cross');

    final String prompt = QaService.readingUserPrompt(
      'Dự án mới?',
      <CardPick>[
        CardPick(cards[1], CardOrientation.upright),
        CardPick(cards[0], CardOrientation.reversed),
      ],
      'vi',
      spread: celtic,
    );

    expect(prompt, contains('Kiểu trải: Celtic Cross'));
    expect(prompt, contains('2. Thử thách (điều cắt ngang hoặc cản trở)'));
    expect(prompt, contains('10. Kết quả'));
    expect(prompt, contains('[1] Hiện tại: The Magician - Xuôi'));
    expect(prompt, contains('[2] Thử thách: The Fool - Ngược'));
    expect(prompt, contains('(2/10 lá'));
    expect(prompt, contains('chưa rút đủ lá'));

    final String full = QaService.readingUserPrompt(
      '',
      <CardPick>[CardPick(cards[2], CardOrientation.upright)],
      'en',
      spread: spreadById('one_card'),
    );
    expect(full, contains('Spread: Message'));
    expect(full, contains('[1] Message: The High Priestess - Upright'));
    expect(full, isNot(contains('not complete')));
  });

  test('free spread keeps the ordered-flow prompt', () async {
    final List<TarotCard> cards = await TarotRepository().cards('en');
    final String prompt = QaService.readingUserPrompt(
      'Work?',
      <CardPick>[CardPick(cards.first, CardOrientation.upright)],
      'en',
      spread: spreadById('free'),
    );
    expect(prompt, isNot(contains('Spread:')));
    expect(prompt, contains('[1] The Fool - Upright'));
  });

  test('empty question asks for a general reading', () async {
    final List<TarotCard> cards = await TarotRepository().cards('en');
    final String prompt = QaService.readingUserPrompt(
        '  ',
        <CardPick>[
          CardPick(cards.first, CardOrientation.upright),
        ],
        'en');
    expect(prompt, contains('give a general reading'));
  });
}
