import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../models/tarot_card.dart';
import '../widgets/section_block.dart';

/// Full card reference: art, correspondences, and the upright/reversed halves
/// on their own tabs so a long meaning never buries the one you came for.
class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({super.key, required this.card});

  final TarotCard card;

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(card.name),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: strings.overview),
              Tab(text: '⬆️ ${strings.upright}'),
              Tab(text: '⬇️ ${strings.reversed}'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _OverviewTab(card: card, strings: strings),
            _CardOrientationTab(
              card: card,
              strings: strings,
              orientation: CardOrientation.upright,
            ),
            _CardOrientationTab(
              card: card,
              strings: strings,
              orientation: CardOrientation.reversed,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.card, required this.strings});

  final TarotCard card;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<(String, String, String)> facts = <(String, String, String)>[
      ('🃏', strings.type, card.type),
      ('🌿', strings.element, card.element),
      ('🔮', strings.astrology, card.astrology),
      ('❓', strings.yesNo, card.yesNo),
    ].where(((String, String, String) item) => item.$3.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              card.assetPath,
              height: 320,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (facts.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final (String icon, String label, String value) in facts)
                InfoChip(label: '$icon $label: $value'),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (card.shortMeaning.isNotEmpty ||
            card.shortReversedMeaning.isNotEmpty) ...<Widget>[
          Text(
            '✨ ${strings.shortMeaning}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          if (card.shortMeaning.isNotEmpty)
            SectionBlock(
              icon: '⬆️',
              title: strings.upright,
              body: card.shortMeaning,
            ),
          if (card.shortReversedMeaning.isNotEmpty)
            SectionBlock(
              icon: '⬇️',
              title: strings.reversed,
              body: card.shortReversedMeaning,
            ),
        ],
        if (card.description.isNotEmpty)
          SectionBlock(
            icon: '🖼️',
            title: strings.cardDescription,
            body: card.description,
          ),
        if (card.symbols.isNotEmpty) ...<Widget>[
          Text(
            '🔍 ${strings.symbols}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (final CardSymbol symbol in card.symbols)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: <TextSpan>[
                    const TextSpan(text: '• '),
                    TextSpan(
                      text: symbol.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (symbol.meaning.isNotEmpty)
                      TextSpan(text: ': ${symbol.meaning}'),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CardOrientationTab extends StatelessWidget {
  const _CardOrientationTab({
    required this.card,
    required this.strings,
    required this.orientation,
  });

  final TarotCard card;
  final Strings strings;
  final CardOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CardSection section = card.section(orientation);
    final List<String> keywords = card.keywords(orientation);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        if (keywords.isNotEmpty) ...<Widget>[
          Text(
            '🏷️ ${strings.keywords}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String keyword in keywords)
                InfoChip(label: keyword, emphasis: true),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (section.description.isNotEmpty)
          SectionBlock(
            icon: '📖',
            title: strings.meaning,
            body: section.description,
          ),
        if (section.love.isNotEmpty)
          SectionBlock(icon: '❤️', title: strings.love, body: section.love),
        if (section.career.isNotEmpty)
          SectionBlock(icon: '💼', title: strings.career, body: section.career),
        if (section.finances.isNotEmpty)
          SectionBlock(
            icon: '💰',
            title: strings.finances,
            body: section.finances,
          ),
        if (section.feelings.isNotEmpty)
          SectionBlock(
            icon: '💭',
            title: strings.feelings,
            body: section.feelings,
          ),
        if (section.actions.isNotEmpty)
          SectionBlock(
            icon: '🎯',
            title: strings.actions,
            body: section.actions,
          ),
        if (section.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text(strings.noCardsFound)),
          ),
      ],
    );
  }
}
