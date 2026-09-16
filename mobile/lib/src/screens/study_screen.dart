import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../models/reference_chunk.dart';
import '../models/study_draw.dart';
import '../models/tarot_card.dart';
import '../services/grading_service.dart';
import '../services/study_service.dart';
import '../theme.dart';
import '../widgets/neu.dart';

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
    final NeuTokens neu = context.neu;
    final StudyProgress progress = services.study.progress(
      services.settings.language,
      deckSize: _deckSize,
    );
    final StudyDraw? draw = _draw;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: <Widget>[
        if (_deckSize > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: NeuChip(
              label: strings.cycle(progress.cycle, progress.remaining),
              icon: Icons.donut_large,
              color: neu.blue,
              selected: true,
            ),
          ),
        const SizedBox(height: 18),
        if (draw == null)
          NeuBox(
            color: neu.yellow,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.school, color: neu.onAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.studyIntro,
                    style: TextStyle(
                      color: neu.onAccent,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _DrawCardView(draw: draw, strings: strings),
        const SizedBox(height: 16),
        NeuButton(
          label: draw == null ? strings.drawNew : strings.drawAnother,
          icon: Icons.style,
          color: neu.violet,
          busy: _drawing,
          onPressed: _drawing ? null : _drawCard,
        ),
        if (draw != null) ...<Widget>[
          const SizedBox(height: 28),
          NeuField(
            controller: _answer,
            labelText: strings.yourAnswer,
            hintText: strings.answerPlaceholder,
            minLines: 4,
            maxLines: 10,
          ),
          if (_warning != null) ...<Widget>[
            const SizedBox(height: 10),
            NeuBox(
              color: neu.red,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.warning_amber, size: 18, color: neu.onAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _warning!,
                      style: TextStyle(
                        color: neu.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          NeuButton(
            label: _grading ? strings.grading : strings.gradeAnswer,
            icon: Icons.fact_check,
            busy: _grading,
            onPressed: _grading ? null : _grade,
          ),
        ],
        if (_outcome != null) ...<Widget>[
          const SizedBox(height: 28),
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
    final NeuTokens neu = context.neu;

    return NeuBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NeuBox(
                padding: const EdgeInsets.all(4),
                shadow: false,
                borderWidth: 2,
                radius: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    draw.assetPath,
                    width: 86,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 86),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      draw.cardName.toUpperCase(),
                      style: TextStyle(
                        color: neu.line,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    NeuChip(
                      label: draw.facetLabel,
                      color: neu.yellow,
                      selected: true,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          NeuSection(
            icon: Icons.help_outline,
            title: strings.question,
            body: draw.question,
            color: neu.blue,
          ),
          NeuSection(
            icon: Icons.lightbulb,
            title: strings.hint,
            body: draw.hint,
            color: neu.yellow,
          ),
        ],
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
    final NeuTokens neu = context.neu;
    final GradeResult? grade = outcome.grade;

    return NeuBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (grade != null) ...<Widget>[
            Row(
              children: <Widget>[
                NeuBox(
                  color: grade.passed ? neu.green : neu.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    '${grade.score}/100',
                    style: TextStyle(
                      color: neu.onAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: NeuChip(
                    label: grade.passed ? strings.passed : strings.notPassed,
                    icon: grade.passed ? Icons.check_circle : Icons.cancel,
                    color: grade.passed ? neu.green : neu.red,
                    selected: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _PointList(
              icon: Icons.check,
              title: strings.correctPoints,
              items: grade.correctPoints,
              color: neu.green,
            ),
            _PointList(
              icon: Icons.add,
              title: strings.missingPoints,
              items: grade.missingPoints,
              color: neu.yellow,
            ),
            _PointList(
              icon: Icons.priority_high,
              title: strings.incorrectPoints,
              items: grade.incorrectPoints,
              color: neu.red,
            ),
            if (grade.feedback.isNotEmpty)
              NeuSection(
                icon: Icons.rate_review,
                title: strings.feedback,
                body: grade.feedback,
                color: neu.blue,
              ),
            if (grade.nextHint.isNotEmpty)
              NeuSection(
                icon: Icons.arrow_forward,
                title: strings.nextHint,
                body: grade.nextHint,
                color: neu.violet,
              ),
          ] else if (outcome.error != null)
            NeuBox(
              color: neu.red,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.error_outline, size: 18, color: neu.onAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      outcome.error!,
                      style: TextStyle(
                        color: neu.onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (outcome.chunks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _ReferenceList(
              chunks: outcome.chunks,
              title: strings.referenceChunks,
            ),
          ],
        ],
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final NeuTokens neu = context.neu;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NeuHeading(icon: icon, title: title, color: color),
          const SizedBox(height: 8),
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: neu.line, width: 2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Collapsed by default: the retrieved chunks are long, and most of the time
/// the grade itself is what the learner wants.
class _ReferenceList extends StatefulWidget {
  const _ReferenceList({required this.chunks, required this.title});

  final List<ReferenceChunk> chunks;
  final String title;

  @override
  State<_ReferenceList> createState() => _ReferenceListState();
}

class _ReferenceListState extends State<_ReferenceList> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NeuBox(
          color: Theme.of(context).colorScheme.surface,
          borderWidth: 2,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: <Widget>[
              Icon(Icons.menu_book, size: 16, color: neu.line),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.title.toUpperCase()} (${widget.chunks.length})',
                  style: TextStyle(
                    color: neu.line,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: neu.line,
              ),
            ],
          ),
        ),
        if (_open) ...<Widget>[
          const SizedBox(height: 12),
          for (final ReferenceChunk chunk in widget.chunks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: NeuChip(
                      label: chunk.title.isEmpty ? chunk.label : chunk.title,
                      color: neu.blue,
                      selected: true,
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    chunk.text,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
