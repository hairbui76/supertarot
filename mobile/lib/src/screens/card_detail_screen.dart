import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../models/tarot_card.dart';
import '../theme.dart';
import '../widgets/neu.dart';

/// Full card reference: art, correspondences, and the upright/reversed halves
/// on their own tabs so a long meaning never buries the one you came for.
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({super.key, required this.card});

  final TarotCard card;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);
    final NeuTokens neu = context.neu;

    final List<(IconData, String, Color)> tabs = <(IconData, String, Color)>[
      (Icons.auto_awesome, strings.overview, neu.yellow),
      (Icons.arrow_upward, strings.upright, neu.green),
      (Icons.arrow_downward, strings.reversed, neu.red),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
          child: NeuIconButton(
            icon: Icons.arrow_back,
            size: 40,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        leadingWidth: 64,
        title: Text(widget.card.name.toUpperCase()),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < tabs.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: NeuBox(
                      color: _tab == i
                          ? tabs[i].$3
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      shadow: _tab == i,
                      borderWidth: 2,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onTap: () => setState(() => _tab = i),
                      child: Column(
                        children: <Widget>[
                          Icon(tabs[i].$1, size: 17, color: neu.line),
                          const SizedBox(height: 3),
                          Text(
                            tabs[i].$2.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: neu.line,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (_tab) {
              0 => _OverviewTab(card: widget.card, strings: strings),
              1 => _CardOrientationTab(
                  card: widget.card,
                  strings: strings,
                  orientation: CardOrientation.upright,
                ),
              _ => _CardOrientationTab(
                  card: widget.card,
                  strings: strings,
                  orientation: CardOrientation.reversed,
                ),
            },
          ),
        ],
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
    final NeuTokens neu = context.neu;
    final List<(IconData, String, String)> facts = <(IconData, String, String)>[
      (Icons.style, strings.type, card.type),
      (Icons.eco, strings.element, card.element),
      (Icons.nightlight, strings.astrology, card.astrology),
      (Icons.help_outline, strings.yesNo, card.yesNo),
    ].where(((IconData, String, String) item) => item.$3.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      children: <Widget>[
        Center(
          child: NeuBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                card.assetPath,
                height: 320,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        if (facts.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: <Widget>[
              for (final (IconData icon, String label, String value) in facts)
                NeuChip(label: '$label: $value', icon: icon),
            ],
          ),
          const SizedBox(height: 26),
        ],
        if (card.shortMeaning.isNotEmpty ||
            card.shortReversedMeaning.isNotEmpty) ...<Widget>[
          NeuHeading(
            icon: Icons.bolt,
            title: strings.shortMeaning,
            color: neu.yellow,
          ),
          const SizedBox(height: 12),
          if (card.shortMeaning.isNotEmpty)
            NeuSection(
              icon: Icons.arrow_upward,
              title: strings.upright,
              body: card.shortMeaning,
              color: neu.green,
            ),
          if (card.shortReversedMeaning.isNotEmpty)
            NeuSection(
              icon: Icons.arrow_downward,
              title: strings.reversed,
              body: card.shortReversedMeaning,
              color: neu.red,
            ),
        ],
        if (card.description.isNotEmpty)
          NeuSection(
            icon: Icons.image,
            title: strings.cardDescription,
            body: card.description,
            color: neu.blue,
          ),
        if (card.symbols.isNotEmpty) ...<Widget>[
          NeuHeading(
            icon: Icons.search,
            title: strings.symbols,
            color: neu.violet,
          ),
          const SizedBox(height: 10),
          for (final CardSymbol symbol in card.symbols)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    decoration: BoxDecoration(
                      color: neu.violet,
                      border: Border.all(color: neu.line, width: 2),
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: <TextSpan>[
                          TextSpan(
                            text: symbol.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (symbol.meaning.isNotEmpty)
                            TextSpan(text: ': ${symbol.meaning}'),
                        ],
                      ),
                    ),
                  ),
                ],
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
    final NeuTokens neu = context.neu;
    final CardSection section = card.section(orientation);
    final List<String> keywords = card.keywords(orientation);
    final Color accent =
        orientation == CardOrientation.upright ? neu.green : neu.red;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      children: <Widget>[
        if (keywords.isNotEmpty) ...<Widget>[
          NeuHeading(
            icon: Icons.sell,
            title: strings.keywords,
            color: accent,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: <Widget>[
              for (final String keyword in keywords)
                NeuChip(label: keyword, color: accent, selected: true),
            ],
          ),
          const SizedBox(height: 26),
        ],
        if (section.description.isNotEmpty)
          NeuSection(
            icon: Icons.menu_book,
            title: strings.meaning,
            body: section.description,
            color: accent,
          ),
        if (section.love.isNotEmpty)
          NeuSection(
            icon: Icons.favorite,
            title: strings.love,
            body: section.love,
            color: neu.red,
          ),
        if (section.career.isNotEmpty)
          NeuSection(
            icon: Icons.work,
            title: strings.career,
            body: section.career,
            color: neu.blue,
          ),
        if (section.finances.isNotEmpty)
          NeuSection(
            icon: Icons.payments,
            title: strings.finances,
            body: section.finances,
            color: neu.green,
          ),
        if (section.feelings.isNotEmpty)
          NeuSection(
            icon: Icons.psychology,
            title: strings.feelings,
            body: section.feelings,
            color: neu.violet,
          ),
        if (section.actions.isNotEmpty)
          NeuSection(
            icon: Icons.bolt,
            title: strings.actions,
            body: section.actions,
            color: neu.yellow,
          ),
        if (section.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: NeuBox(
                color: neu.red,
                child: Text(
                  strings.noCardsFound,
                  style: TextStyle(
                    color: neu.onAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
