import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/reading_history.dart';
import '../l10n/strings.dart';
import '../models/reference_chunk.dart';
import '../models/spread.dart';
import '../models/tarot_card.dart';
import '../services/qa_service.dart';
import '../theme.dart';
import '../widgets/markup_text.dart';
import '../widgets/neu.dart';

/// Question on top, then the spread, the drawn cards in order, and the
/// reading.
///
/// With cards picked, the answer reads exactly those cards in their
/// orientation, card N in position N of the chosen spread. With none, it falls
/// back to freeform Q&A over the on-device index. Only the written answer
/// needs a provider key.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _question = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _latestKey = GlobalKey();
  List<SavedReading> _history = <SavedReading>[];
  final Set<String> _expanded = <String>{};
  List<CardPick> _picks = <CardPick>[];
  SpreadDefinition _spread = spreadById('free');
  bool _busy = false;
  bool _historyRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_historyRequested) {
      return;
    }
    _historyRequested = true;
    final AppServices services = AppScope.of(context);
    services.history.load(services.repository).then((List<SavedReading> saved) {
      if (mounted) {
        setState(() => _history = saved);
      }
    });
  }

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy && (_picks.isNotEmpty || _question.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    FocusScope.of(context).unfocus();

    final AppServices services = AppScope.of(context);
    final String language = services.settings.language;
    final String question = _question.text.trim();
    final List<CardPick> picks = List<CardPick>.unmodifiable(_picks);
    setState(() => _busy = true);

    final QaResult result = picks.isEmpty
        ? await services.qa.ask(settings: services.settings, query: question)
        : await services.qa.interpret(
            settings: services.settings,
            question: question,
            picks: picks,
            spread: _spread,
          );
    final SavedReading saved = await services.history.add(result, language);

    if (!mounted) {
      return;
    }
    setState(() {
      _history = <SavedReading>[saved, ..._history]
          .take(ReadingHistory.maxEntries)
          .toList();
      _expanded.add(saved.id);
      _busy = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _latestKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openPicker() async {
    final AppServices services = AppScope.of(context);
    final List<TarotCard> cards = await services.repository.cards(
      services.settings.language,
    );
    if (!mounted) {
      return;
    }
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) => _CardPickerSheet(
        cards: cards,
        spread: _spread,
        language: services.settings.language,
        initial: _picks,
        onChanged: (List<CardPick> picks) => setState(() => _picks = picks),
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final List<CardPick> next = List<CardPick>.of(_picks);
      final CardPick moved = next.removeAt(oldIndex);
      next.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
      _picks = next;
    });
  }

  /// Switching to a smaller spread drops the cards that no longer have a
  /// position, keeping the first ones in order.
  void _selectSpread(SpreadDefinition spread) {
    setState(() {
      _spread = spread;
      if (_picks.length > spread.maxCards) {
        _picks = _picks.take(spread.maxCards).toList();
      }
    });
  }

  void _flip(int index) {
    setState(() {
      _picks = List<CardPick>.of(_picks)..[index] = _picks[index].flipped();
    });
  }

  void _remove(int index) {
    setState(() => _picks = List<CardPick>.of(_picks)..removeAt(index));
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
    });
  }

  /// Puts a saved reading's question and cards back in the form.
  void _reuse(SavedReading reading) {
    setState(() {
      _question.text = reading.result.query;
      _picks = List<CardPick>.of(reading.result.picks);
      _spread = spreadById(reading.result.spreadId);
    });
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _delete(SavedReading reading) async {
    setState(() {
      _history =
          _history.where((SavedReading r) => r.id != reading.id).toList();
      _expanded.remove(reading.id);
    });
    await AppScope.of(context).history.remove(reading.id);
  }

  Future<void> _clearHistory(Strings strings) async {
    final ReadingHistory history = AppScope.of(context).history;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(strings.clearHistoryConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _history = <SavedReading>[];
      _expanded.clear();
    });
    await history.clear();
  }

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);
    final NeuTokens neu = context.neu;
    final String language = AppScope.of(context).settings.language;
    final SpreadPosition? next = _spread.positionAt(_picks.length);

    // A plain Column rather than a lazy ListView: the newest reading must be
    // built for Scrollable.ensureVisible to reach it below the form.
    return SingleChildScrollView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NeuField(
            controller: _question,
            labelText: strings.question,
            hintText: strings.askPlaceholder,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          _SpreadSelector(
            spread: _spread,
            language: language,
            strings: strings,
            onChanged: _busy ? null : _selectSpread,
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: NeuHeading(
                  icon: Icons.style,
                  title: _spread.isFree
                      ? (_picks.isEmpty
                          ? strings.pickedCards
                          : '${strings.pickedCards} · ${_picks.length}')
                      : '${strings.pickedCards} · '
                          '${_picks.length}/${_spread.maxCards}',
                  color: neu.violet,
                ),
              ),
              if (_picks.isNotEmpty)
                NeuChip(
                  label: strings.clearCards,
                  icon: Icons.close,
                  dense: true,
                  onTap: _busy
                      ? null
                      : () => setState(() => _picks = <CardPick>[]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_picks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                strings.noCardsPicked,
                style: TextStyle(
                  color: neu.line.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            )
          else ...<Widget>[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _picks.length,
              // CI builds on latest stable, where onReorder is deprecated for
              // onReorderItem; that callback does not exist yet in Flutter
              // 3.41, so keep the old one until local toolchains catch up.
              // ignore: deprecated_member_use
              onReorder: _reorder,
              proxyDecorator: (Widget child, int index, Animation<double> _) =>
                  Material(type: MaterialType.transparency, child: child),
              itemBuilder: (BuildContext context, int index) => _PickTile(
                key: ValueKey<String>(_picks[index].card.name),
                index: index,
                pick: _picks[index],
                position: _spread.positionAt(index),
                language: language,
                strings: strings,
                onFlip: () => _flip(index),
                onRemove: () => _remove(index),
              ),
            ),
            if (_picks.length > 1)
              Text(
                strings.dragToReorder,
                style: TextStyle(
                  color: neu.line.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
          if (next != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '${strings.spreadNextPosition('${_picks.length + 1}. '
                  '${next.label(language)}')}'
              '${_picks.isEmpty ? '' : ' · ${strings.spreadMissingCount(_spread.maxCards - _picks.length)}'}',
              style: TextStyle(
                color: neu.line,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: NeuButton(
                  label: strings.pickCards,
                  icon: Icons.add,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  onPressed: _busy ? null : _openPicker,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeuButton(
                  label: _busy
                      ? strings.thinking
                      : (_picks.isEmpty ? strings.send : strings.interpret),
                  icon: Icons.auto_awesome,
                  busy: _busy,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (_history.isEmpty)
            Text(
              strings.askIntro,
              style: TextStyle(
                color: neu.line.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: NeuHeading(
                    icon: Icons.history,
                    title: '${strings.readingHistory} · ${_history.length}',
                    color: neu.blue,
                  ),
                ),
                NeuChip(
                  label: strings.clearHistory,
                  icon: Icons.delete_sweep,
                  dense: true,
                  onTap: _busy ? null : () => _clearHistory(strings),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < _history.length; i++)
              _ReadingCard(
                key: i == 0 ? _latestKey : ValueKey<String>(_history[i].id),
                reading: _history[i],
                strings: strings,
                expanded: _expanded.contains(_history[i].id),
                onToggle: () => _toggleExpanded(_history[i].id),
                onReuse: () => _reuse(_history[i]),
                onDelete: () => _delete(_history[i]),
              ),
          ],
        ],
      ),
    );
  }
}

/// Dropdown over every spread plus its description and numbered positions.
class _SpreadSelector extends StatelessWidget {
  const _SpreadSelector({
    required this.spread,
    required this.language,
    required this.strings,
    required this.onChanged,
  });

  final SpreadDefinition spread;
  final String language;
  final Strings strings;
  final ValueChanged<SpreadDefinition>? onChanged;

  String _itemLabel(SpreadDefinition item) => item.isFree
      ? item.name(language)
      : '${item.name(language)} · ${strings.spreadCardCount(item.maxCards)}';

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final Color surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.spreadLabel.toUpperCase(),
          style: TextStyle(
            color: neu.line,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        NeuBox(
          color: surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: spread.id,
              isExpanded: true,
              menuMaxHeight: 440,
              dropdownColor: surface,
              borderRadius: BorderRadius.circular(8),
              icon: Icon(Icons.expand_more, color: neu.line),
              style: TextStyle(
                color: neu.line,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              items: <DropdownMenuItem<String>>[
                for (final SpreadDefinition item in tarotSpreads)
                  DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(
                      _itemLabel(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (String? id) => onChanged!(spreadById(id)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          spread.description(language),
          style: TextStyle(
            color: neu.line.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        if (!spread.isFree) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (int i = 0; i < spread.positions.length; i++)
                NeuChip(
                  label: '${i + 1}. ${spread.positions[i].label(language)}',
                  dense: true,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One picked card in the ordered list: position, thumbnail, orientation
/// toggle and remove. Long-press anywhere or drag the handle to reorder.
class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.index,
    required this.pick,
    required this.position,
    required this.language,
    required this.strings,
    required this.onFlip,
    required this.onRemove,
  });

  final int index;
  final CardPick pick;
  final SpreadPosition? position;
  final String language;
  final Strings strings;
  final VoidCallback onFlip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;

    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeuBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.drag_indicator, color: neu.line),
                ),
              ),
              _PositionBadge(position: index + 1),
              const SizedBox(width: 10),
              _CardThumb(pick: pick, width: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (position != null) ...<Widget>[
                      Text(
                        position!.label(language).toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neu.line.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (position!.hint(language).isNotEmpty)
                        Text(
                          position!.hint(language),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neu.line.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      pick.card.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.line,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    NeuChip(
                      label:
                          pick.isReversed ? strings.reversed : strings.upright,
                      icon: pick.isReversed ? Icons.south : Icons.north,
                      color: neu.red,
                      selected: pick.isReversed,
                      dense: true,
                      onTap: onFlip,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              NeuIconButton(
                icon: Icons.close,
                size: 34,
                tooltip: strings.removeCard,
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.position, this.size = 28});

  final int position;
  final double size;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    return NeuBox(
      color: neu.yellow,
      shadow: false,
      radius: 6,
      borderWidth: 2,
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      child: Text(
        '$position',
        style: TextStyle(
          color: neu.onAccent,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.46,
        ),
      ),
    );
  }
}

/// Card image at a fixed width, turned upside down when reversed.
class _CardThumb extends StatelessWidget {
  const _CardThumb({required this.pick, required this.width});

  final CardPick pick;
  final double width;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    return Container(
      width: width,
      height: width * 1.65,
      decoration: BoxDecoration(
        border: Border.all(color: neu.line, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: RotatedBox(
        quarterTurns: pick.isReversed ? 2 : 0,
        child: Image.asset(
          pick.card.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.hide_image, size: 16, color: neu.line),
        ),
      ),
    );
  }
}

/// One saved reading. Collapsed it shows the question, cards and a two-line
/// preview; expanded it shows the full answer. The header carries the date
/// plus "ask again" (refill the form) and delete.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    super.key,
    required this.reading,
    required this.strings,
    required this.expanded,
    required this.onToggle,
    required this.onReuse,
    required this.onDelete,
  });

  final SavedReading reading;
  final Strings strings;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onReuse;
  final VoidCallback onDelete;

  static String _formatDate(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}/${time.year} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final QaResult result = reading.result;
    final List<ReferenceChunk> chunks = result.chunks;
    final String title =
        result.query.isNotEmpty ? result.query : strings.generalReading;
    final SpreadDefinition? spread =
        result.spreadId == null ? null : spreadById(result.spreadId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeuBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.schedule, size: 16, color: neu.line),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDate(reading.createdAt),
                    style: TextStyle(
                      color: neu.line.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                NeuIconButton(
                  icon: Icons.replay,
                  size: 34,
                  tooltip: strings.reuseReading,
                  onPressed: onReuse,
                ),
                const SizedBox(width: 8),
                NeuIconButton(
                  icon: Icons.delete_outline,
                  size: 34,
                  tooltip: strings.deleteReading,
                  onPressed: onDelete,
                ),
                const SizedBox(width: 8),
                NeuIconButton(
                  icon: expanded ? Icons.expand_less : Icons.expand_more,
                  size: 34,
                  color: neu.yellow,
                  onPressed: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onToggle,
              child: NeuBox(
                color: neu.yellow,
                shadow: false,
                borderWidth: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(
                  title,
                  maxLines: expanded ? null : 2,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.onAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (spread != null && !spread.isFree) ...<Widget>[
              NeuChip(
                label: spread.name(reading.language),
                icon: Icons.grid_view,
                dense: true,
              ),
              const SizedBox(height: 12),
            ],
            if (result.picks.isNotEmpty) ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (int i = 0; i < result.picks.length; i++)
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        _CardThumb(pick: result.picks[i], width: 38),
                        Positioned(
                          left: -4,
                          top: -4,
                          child: _PositionBadge(position: i + 1, size: 20),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (expanded) ...<Widget>[
              MarkupText(result.answer),
              if (chunks.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    for (final ReferenceChunk chunk in chunks.take(5))
                      NeuChip(label: chunk.cardName, dense: true),
                  ],
                ),
              ],
            ] else
              GestureDetector(
                onTap: onToggle,
                child: Text(
                  result.answer.replaceAll('**', '').replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.line.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-height sheet over all 78 cards. Tapping a card appends it in the
/// current "add as" orientation; tapping it again takes it back out. Every
/// change is pushed to the screen immediately, so dismissing the sheet by
/// swiping keeps the selection.
class _CardPickerSheet extends StatefulWidget {
  const _CardPickerSheet({
    required this.cards,
    required this.spread,
    required this.language,
    required this.initial,
    required this.onChanged,
  });

  final List<TarotCard> cards;
  final SpreadDefinition spread;
  final String language;
  final List<CardPick> initial;
  final ValueChanged<List<CardPick>> onChanged;

  @override
  State<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends State<_CardPickerSheet> {
  final TextEditingController _search = TextEditingController();
  late List<CardPick> _picks = List<CardPick>.of(widget.initial);
  CardOrientation _addAs = CardOrientation.upright;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _indexOf(TarotCard card) =>
      _picks.indexWhere((CardPick pick) => pick.card.name == card.name);

  void _toggle(TarotCard card) {
    final int index = _indexOf(card);
    if (index < 0 && _picks.length >= widget.spread.maxCards) {
      return;
    }
    setState(() {
      _picks = List<CardPick>.of(_picks);
      if (index >= 0) {
        _picks.removeAt(index);
      } else {
        _picks.add(CardPick(card, _addAs));
      }
    });
    widget.onChanged(_picks);
  }

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);
    final NeuTokens neu = context.neu;
    final List<TarotCard> visible = _query.isEmpty
        ? widget.cards
        : widget.cards
            .where(
              (TarotCard card) =>
                  card.name.toLowerCase().contains(_query) ||
                  card.type.toLowerCase().contains(_query),
            )
            .toList(growable: false);
    final int max = widget.spread.maxCards;
    final bool full = _picks.length >= max;
    final SpreadPosition? next = widget.spread.positionAt(_picks.length);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${strings.pickCards} · ${_picks.length}/$max',
                      style: TextStyle(
                        color: neu.line,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  NeuButton(
                    label: strings.done,
                    icon: Icons.check,
                    expanded: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    strings.addAs,
                    style: TextStyle(
                      color: neu.line,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  NeuChip(
                    label: strings.upright,
                    icon: Icons.north,
                    selected: _addAs == CardOrientation.upright,
                    onTap: () =>
                        setState(() => _addAs = CardOrientation.upright),
                  ),
                  NeuChip(
                    label: strings.reversed,
                    icon: Icons.south,
                    color: neu.red,
                    selected: _addAs == CardOrientation.reversed,
                    onTap: () =>
                        setState(() => _addAs = CardOrientation.reversed),
                  ),
                ],
              ),
            ),
            if (next != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  strings.spreadNextPosition(
                    '${_picks.length + 1}. ${next.label(widget.language)}',
                  ),
                  style:
                      TextStyle(color: neu.line, fontWeight: FontWeight.w800),
                ),
              ),
            if (full)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  strings.maxCards(max),
                  style: TextStyle(color: neu.red, fontWeight: FontWeight.w800),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: NeuField(
                controller: _search,
                hintText: strings.searchCards,
                prefixIcon: Icons.search,
                onChanged: (String value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.52,
                ),
                itemCount: visible.length,
                itemBuilder: (BuildContext context, int index) {
                  final TarotCard card = visible[index];
                  final int position = _indexOf(card);
                  return _PickerTile(
                    card: card,
                    pick: position < 0 ? null : _picks[position],
                    position: position < 0 ? null : position + 1,
                    dimmed: full && position < 0,
                    onTap: () => _toggle(card),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.card,
    required this.pick,
    required this.position,
    required this.dimmed,
    required this.onTap,
  });

  final TarotCard card;
  final CardPick? pick;
  final int? position;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final bool picked = pick != null;
    final Color surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: NeuBox(
              color: picked ? neu.yellow : surface,
              padding: EdgeInsets.zero,
              radius: 6,
              borderWidth: picked ? 3 : 2,
              shadow: picked,
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: (pick?.isReversed ?? false) ? 2 : 0,
                        child: Image.asset(
                          card.assetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.hide_image, color: neu.line),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: picked ? neu.yellow : surface,
                        border: Border(
                          top: BorderSide(color: neu.line, width: 2),
                        ),
                      ),
                      child: Text(
                        card.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: picked ? neu.onAccent : neu.line,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (position != null)
            Positioned(
              left: -5,
              top: -5,
              child: _PositionBadge(position: position!, size: 24),
            ),
        ],
      ),
    );
  }
}
