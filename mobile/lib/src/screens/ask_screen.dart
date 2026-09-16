import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../models/reference_chunk.dart';
import '../services/qa_service.dart';
import '../theme.dart';
import '../widgets/markup_text.dart';
import '../widgets/neu.dart';

/// Freeform tarot Q&A. Retrieval runs on device; only the written answer needs
/// a provider key.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _question = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Turn> _turns = <_Turn>[];
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final String query = _question.text.trim();
    if (query.isEmpty || _busy) {
      return;
    }

    final AppServices services = AppScope.of(context);
    setState(() {
      _turns.add(_Turn.question(query));
      _busy = true;
      _question.clear();
    });
    _scrollToEnd();

    final QaResult result = await services.qa.ask(
      settings: services.settings,
      query: query,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _turns.add(_Turn.answer(result));
      _busy = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);
    final NeuTokens neu = context.neu;

    return Column(
      children: <Widget>[
        Expanded(
          child: _turns.isEmpty
              ? _EmptyState(strings: strings)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  itemCount: _turns.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _TurnView(turn: _turns[index]),
                ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NeuChip(
              label: strings.thinking,
              icon: Icons.hourglass_top,
              color: neu.yellow,
              selected: true,
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: NeuField(
                    controller: _question,
                    hintText: strings.askPlaceholder,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                const SizedBox(width: 10),
                NeuIconButton(
                  icon: Icons.send,
                  color: neu.yellow,
                  size: 52,
                  tooltip: strings.send,
                  onPressed: _busy ? null : _ask,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings});

  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Stacked offset squares: a flat, gradient-free "3D" motif built
            // from the same border and shadow primitives as everything else.
            SizedBox(
              height: 118,
              width: 118,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    child: NeuBox(
                      color: neu.blue,
                      width: 78,
                      height: 78,
                      padding: EdgeInsets.zero,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 24,
                    child: NeuBox(
                      color: neu.red,
                      width: 78,
                      height: 78,
                      padding: EdgeInsets.zero,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    top: 40,
                    child: NeuBox(
                      color: neu.yellow,
                      width: 78,
                      height: 78,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 34,
                        color: neu.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Text(
              strings.askIntro,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neu.line,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Turn {
  const _Turn._({required this.isQuestion, required this.text, this.result});

  factory _Turn.question(String text) => _Turn._(isQuestion: true, text: text);

  factory _Turn.answer(QaResult result) =>
      _Turn._(isQuestion: false, text: result.answer, result: result);

  final bool isQuestion;
  final String text;
  final QaResult? result;
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;

    if (turn.isQuestion) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 36),
          child: NeuBox(
            color: neu.yellow,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(
              turn.text,
              style: TextStyle(
                color: neu.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final List<ReferenceChunk> chunks =
        turn.result?.chunks ?? const <ReferenceChunk>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18, right: 28),
      child: NeuBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MarkupText(turn.text),
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
          ],
        ),
      ),
    );
  }
}
