import 'package:flutter_test/flutter_test.dart';
import 'package:supertarot_mobile/src/data/tarot_repository.dart';
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
