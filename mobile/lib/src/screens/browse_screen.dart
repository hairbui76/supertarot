import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/tarot_repository.dart';
import '../l10n/strings.dart';
import '../models/tarot_card.dart';
import 'card_detail_screen.dart';

/// Suit list plus a search field over all 78 cards.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final Strings strings = AppScope.stringsOf(context);
    final String language = services.settings.language;

    return FutureBuilder<List<TarotCard>>(
      future: services.repository.cards(language),
      builder: (BuildContext context, AsyncSnapshot<List<TarotCard>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<TarotCard> cards = snapshot.data!;

        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _search,
                onChanged: (String value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: strings.searchCards,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _SuitList(cards: cards, language: language)
                  : _SearchResults(
                      cards: cards
                          .where((TarotCard card) =>
                              card.name.toLowerCase().contains(_query))
                          .toList(growable: false),
                      strings: strings,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SuitList extends StatelessWidget {
  const _SuitList({required this.cards, required this.language});

  final List<TarotCard> cards;
  final String language;

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: suitDefinitions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final SuitDefinition suit = suitDefinitions[index];
        final List<TarotCard> suitCards = cards
            .where((TarotCard card) => card.type == suit.typeFor(language))
            .toList(growable: false);

        return Card(
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Text(suit.emoji, style: const TextStyle(fontSize: 26)),
            title: Text(
              suit.labelFor(language),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${suitCards.length} ${strings.cardCount}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _SuitCardsScreen(
                  title: suit.labelFor(language),
                  cards: suitCards,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.cards, required this.strings});

  final List<TarotCard> cards;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(child: Text(strings.noCardsFound));
    }
    return _CardGrid(cards: cards);
  }
}

class _SuitCardsScreen extends StatelessWidget {
  const _SuitCardsScreen({required this.title, required this.cards});

  final String title;
  final List<TarotCard> cards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _CardGrid(cards: cards),
    );
  }
}

/// Cards stay in the deck order the repository sorted them into.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards});

  final List<TarotCard> cards;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemCount: cards.length,
      itemBuilder: (BuildContext context, int index) {
        final TarotCard card = cards[index];
        return _CardTile(card: card);
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});

  final TarotCard card;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CardDetailScreen(card: card),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Image.asset(
                  card.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
