import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/settings_store.dart';
import '../data/tarot_repository.dart';
import '../l10n/strings.dart';
import '../models/tarot_card.dart';
import '../theme.dart';
import '../widgets/neu.dart';
import '../widgets/suit_glyph.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: NeuField(
                controller: _search,
                hintText: strings.searchCards,
                prefixIcon: Icons.search,
                onChanged: (String value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                suffix: _query.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(Icons.close, color: context.neu.line),
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
    final NeuTokens neu = context.neu;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: suitDefinitions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) {
        final SuitDefinition suit = suitDefinitions[index];
        final List<TarotCard> suitCards = cards
            .where((TarotCard card) => card.type == suit.typeFor(language))
            .toList(growable: false);

        return NeuBox(
          color: suit.accent,
          padding: const EdgeInsets.all(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _SuitCardsScreen(
                title: suit.labelFor(language),
                accent: suit.accent,
                cards: suitCards,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              NeuBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shadow: false,
                borderWidth: 2,
                radius: 6,
                padding: const EdgeInsets.all(9),
                child: SuitGlyph(suit.symbol, size: 26, color: neu.line),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      suit.labelFor(language).toUpperCase(),
                      style: TextStyle(
                        color: neu.onAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${suitCards.length} ${strings.cardCount}',
                      style: TextStyle(
                        color: neu.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: neu.onAccent),
            ],
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
      return Center(
        child: NeuBox(
          color: context.neu.red,
          child: Text(
            strings.noCardsFound,
            style: TextStyle(
              color: context.neu.onAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    return CardGrid(cards: cards);
  }
}

class _SuitCardsScreen extends StatelessWidget {
  const _SuitCardsScreen({
    required this.title,
    required this.accent,
    required this.cards,
  });

  final String title;
  final Color accent;
  final List<TarotCard> cards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
          child: NeuIconButton(
            icon: Icons.arrow_back,
            color: accent,
            size: 40,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        leadingWidth: 64,
        title: Text(title.toUpperCase()),
        actions: const <Widget>[GridZoomControls()],
      ),
      body: CardGrid(cards: cards),
    );
  }
}

/// Plus/minus stepper mirroring the pinch gesture, so the zoom is findable
/// without knowing the gesture exists.
class GridZoomControls extends StatelessWidget {
  const GridZoomControls({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final int columns = services.settings.gridColumns;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
      child: Row(
        children: <Widget>[
          NeuIconButton(
            icon: Icons.zoom_in,
            size: 40,
            onPressed: columns > SettingsStore.minGridColumns
                ? () => services.settings.setGridColumns(columns - 1)
                : null,
          ),
          const SizedBox(width: 8),
          NeuIconButton(
            icon: Icons.zoom_out,
            size: 40,
            onPressed: columns < SettingsStore.maxGridColumns
                ? () => services.settings.setGridColumns(columns + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Card grid whose column count is pinch-zoomable between 1 and 5.
///
/// Cards keep the deck order the repository sorted them into. Tile height is
/// computed from the real tile width so the artwork is never cropped at any
/// zoom level, which a fixed `childAspectRatio` cannot do across 1..5 columns.
class CardGrid extends StatefulWidget {
  const CardGrid({super.key, required this.cards});

  final List<TarotCard> cards;

  @override
  State<CardGrid> createState() => _CardGridState();
}

class _CardGridState extends State<CardGrid> {
  /// Card art is roughly 1:1.75. Keeping the tile on that ratio means the
  /// artwork is never cropped, at any column count.
  static const double _artAspect = 0.575;

  /// How far the fingers must spread or close before stepping one column.
  static const double _zoomInRatio = 1.35;
  static const double _zoomOutRatio = 0.75;

  /// Raw pointers rather than a GestureDetector: a scale recognizer competes
  /// with the GridView's own drag recognizer in the gesture arena and loses,
  /// so the pinch never fires. Listener sits outside the arena entirely, which
  /// leaves normal scrolling untouched.
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _referenceDistance;
  bool _pinching = false;

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _referenceDistance = _distance();
      _setPinching(true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.position;

    final double? reference = _referenceDistance;
    if (_pointers.length < 2 || reference == null || reference == 0) {
      return;
    }

    final double current = _distance();
    final double ratio = current / reference;
    // Spreading the fingers means "bigger cards", which is fewer columns.
    if (ratio > _zoomInRatio) {
      _referenceDistance = current;
      _step(-1);
    } else if (ratio < _zoomOutRatio) {
      _referenceDistance = current;
      _step(1);
    }
  }

  void _onPointerRelease(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _referenceDistance = null;
      _setPinching(false);
    }
  }

  double _distance() {
    final List<Offset> points = _pointers.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  void _step(int delta) {
    final SettingsStore settings = AppScope.of(context).settings;
    settings.setGridColumns(settings.gridColumns + delta);
  }

  void _setPinching(bool value) {
    if (_pinching != value) {
      setState(() => _pinching = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int columns = AppScope.of(context).settings.gridColumns;
    const double gap = 14;
    const double horizontalPadding = 20;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerRelease,
      onPointerCancel: _onPointerRelease,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double tileWidth = (constraints.maxWidth -
                  horizontalPadding * 2 -
                  gap * (columns - 1)) /
              columns;
          final double labelHeight = columns >= 4 ? 26 : 34;
          final double tileHeight = tileWidth / _artAspect + labelHeight;

          return GridView.builder(
            // Freeze scrolling mid-pinch so the grid does not slide away while
            // the column count is changing under the fingers.
            physics: _pinching
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              horizontalPadding,
              4,
              horizontalPadding,
              28,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: tileHeight,
            ),
            itemCount: widget.cards.length,
            itemBuilder: (BuildContext context, int index) => _CardTile(
              card: widget.cards[index],
              columns: columns,
            ),
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.columns});

  final TarotCard card;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final bool tight = columns >= 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: NeuBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: EdgeInsets.zero,
            radius: tight ? 4 : 8,
            borderWidth: tight ? 2 : 3,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CardDetailScreen(card: card),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tight ? 2 : 5),
              child: Image.asset(
                card.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Center(child: Icon(Icons.hide_image, color: neu.line)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          card.name,
          maxLines: tight ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: neu.line,
            fontWeight: FontWeight.w800,
            fontSize: tight ? 9.5 : 12,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}
