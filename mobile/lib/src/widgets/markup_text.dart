import 'package:flutter/material.dart';

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
