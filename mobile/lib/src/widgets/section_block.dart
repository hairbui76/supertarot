import 'package:flutter/material.dart';

/// Icon + heading + body paragraph, the shape every card-meaning section uses.
class SectionBlock extends StatelessWidget {
  const SectionBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Renders the lightweight `**bold**` / `•` markup the Q&A prompts ask for.
class MarkupText extends StatelessWidget {
  const MarkupText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final List<TextSpan> spans = <TextSpan>[];
    final RegExp bold = RegExp(r'\*\*(.+?)\*\*', dotAll: true);

    // Normalise markdown list markers to bullets first: the models drift back
    // to "- " despite the prompt asking for "•".
    final String normalized = text
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ');

    int cursor = 0;
    for (final RegExpMatch match in bold.allMatches(normalized)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: normalized.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      cursor = match.end;
    }
    if (cursor < normalized.length) {
      spans.add(TextSpan(text: normalized.substring(cursor)));
    }

    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}

/// Small rounded label used for keywords and correspondences.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.emphasis = false});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: emphasis ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
      ),
    );
  }
}
