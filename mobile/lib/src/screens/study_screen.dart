import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../models/reference_chunk.dart';
import '../models/study_draw.dart';
import '../models/tarot_card.dart';
import '../services/grading_service.dart';
import '../services/study_service.dart';
import '../widgets/section_block.dart';

/// Draw a card, answer the facet question, get it graded against the bundled
/// reference material.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final TextEditingController _answer = TextEditingController();
  StudyDraw? _draw;
  GradingOutcome? _outcome;
  bool _drawing = false;
  bool _grading = false;
  String? _warning;

  int _deckSize = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resume whatever question was left open, so closing the app mid-answer
    // does not burn a card from the cycle.
    final AppServices services = AppScope.of(context);
    _draw ??= services.study.openDraw;
    services.repository.cards(services.settings.language).then(
      (List<TarotCard> cards) {
        if (mounted && _deckSize != cards.length) {
          setState(() => _deckSize = cards.length);
        }
      },
    );
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _drawCard() async {
    final AppServices services = AppScope.of(context);
    setState(() {
      _drawing = true;
      _warning = null;
    });

    final List<TarotCard> cards =
        await services.repository.cards(services.settings.language);
    final StudyDraw draw = await services.study.draw(
      language: services.settings.language,
      cards: cards,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _draw = draw;
      _outcome = null;
      _drawing = false;
      _answer.clear();
    });
  }

  Future<void> _grade() async {
    final StudyDraw? draw = _draw;
    final Strings strings = AppScope.stringsOf(context);
    if (draw == null) {
      return;
    }
    if (_answer.text.trim().isEmpty) {
      setState(() => _warning = strings.emptyAnswerWarning);
      return;
    }

    final AppServices services = AppScope.of(context);
    setState(() {
      _grading = true;
      _warning = null;
    });

    final GradingOutcome outcome = await services.grading.grade(
      settings: services.settings,
      draw: draw,
      answer: _answer.text.trim(),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _outcome = outcome;
      _grading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final Strings strings = AppScope.stringsOf(context);
    final StudyProgress progress = services.study.progress(
      services.settings.language,
      deckSize: _deckSize,
    );
    final StudyDraw? draw = _draw;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _deckSize == 0
                    ? ''
                    : strings.cycle(progress.cycle, progress.remaining),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            if (_drawing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (draw == null) ...<Widget>[
          Text(strings.studyIntro,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
        ] else
          _DrawCardView(draw: draw, strings: strings),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _drawing ? null : _drawCard,
          icon: const Icon(Icons.style_outlined),
          label: Text(draw == null ? strings.drawNew : strings.drawAnother),
        ),
        if (draw != null) ...<Widget>[
          const SizedBox(height: 24),
          Text(
            strings.yourAnswer,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answer,
            minLines: 4,
            maxLines: 10,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: strings.answerPlaceholder),
          ),
          if (_warning != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _warning!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _grading ? null : _grade,
            icon: _grading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: Text(_grading ? strings.grading : strings.gradeAnswer),
          ),
        ],
        if (_outcome != null) ...<Widget>[
          const SizedBox(height: 24),
          _GradeView(outcome: _outcome!, strings: strings),
        ],
      ],
    );
  }
}

class _DrawCardView extends StatelessWidget {
  const _DrawCardView({required this.draw, required this.strings});

  final StudyDraw draw;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    draw.assetPath,
                    width: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 90),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        draw.cardName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draw.facetLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionBlock(
              icon: '❓',
              title: strings.question,
              body: draw.question,
            ),
            SectionBlock(icon: '💡', title: strings.hint, body: draw.hint),
          ],
        ),
      ),
    );
  }
}

class _GradeView extends StatelessWidget {
  const _GradeView({required this.outcome, required this.strings});

  final GradingOutcome outcome;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GradeResult? grade = outcome.grade;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (grade != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '${grade.score}/100',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: grade.passed
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InfoChip(
                    label:
                        grade.passed ? strings.passed : strings.notPassed,
                    emphasis: grade.passed,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _PointList(
                icon: '✅',
                title: strings.correctPoints,
                items: grade.correctPoints,
              ),
              _PointList(
                icon: '➕',
                title: strings.missingPoints,
                items: grade.missingPoints,
              ),
              _PointList(
                icon: '⚠️',
                title: strings.incorrectPoints,
                items: grade.incorrectPoints,
              ),
              if (grade.feedback.isNotEmpty)
                SectionBlock(
                  icon: '📝',
                  title: strings.feedback,
                  body: grade.feedback,
                ),
              if (grade.nextHint.isNotEmpty)
                SectionBlock(
                  icon: '👉',
                  title: strings.nextHint,
                  body: grade.nextHint,
                ),
            ] else if (outcome.error != null)
              Text(
                outcome.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (outcome.chunks.isNotEmpty)
              _ReferenceList(
                chunks: outcome.chunks,
                title: strings.referenceChunks,
              ),
          ],
        ),
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({
    required this.icon,
    required this.title,
    required this.items,
  });

  final String icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$icon $title',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item', style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

/// Collapsed by default: the retrieved chunks are long, and most of the time
/// the grade itself is what the learner wants.
class _ReferenceList extends StatelessWidget {
  const _ReferenceList({required this.chunks, required this.title});

  final List<ReferenceChunk> chunks;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          '📚 $title (${chunks.length})',
          style: theme.textTheme.titleSmall,
        ),
        children: <Widget>[
          for (final ReferenceChunk chunk in chunks)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chunk.title.isEmpty ? chunk.label : chunk.title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(chunk.text, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
