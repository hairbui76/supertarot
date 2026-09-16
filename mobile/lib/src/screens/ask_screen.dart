import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../models/reference_chunk.dart';
import '../services/qa_service.dart';
import '../widgets/section_block.dart';

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

    return Column(
      children: <Widget>[
        Expanded(
          child: _turns.isEmpty
              ? _EmptyState(strings: strings)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _turns.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _TurnView(turn: _turns[index], strings: strings),
                ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(strings.thinking),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _question,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _ask(),
                    decoration:
                        InputDecoration(hintText: strings.askPlaceholder),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : _ask,
                  icon: const Icon(Icons.send_rounded),
                  tooltip: strings.send,
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
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('🔮', style: theme.textTheme.displaySmall),
            const SizedBox(height: 16),
            Text(
              strings.askIntro,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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

  factory _Turn.question(String text) =>
      _Turn._(isQuestion: true, text: text);

  factory _Turn.answer(QaResult result) =>
      _Turn._(isQuestion: false, text: result.answer, result: result);

  final bool isQuestion;
  final String text;
  final QaResult? result;
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn, required this.strings});

  final _Turn turn;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (turn.isQuestion) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            turn.text,
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
      );
    }

    final List<ReferenceChunk> chunks =
        turn.result?.chunks ?? const <ReferenceChunk>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MarkupText(turn.text),
          if (chunks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final ReferenceChunk chunk in chunks.take(5))
                  InfoChip(label: chunk.cardName),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
