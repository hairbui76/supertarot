/// One retrieved slice of tarot reference text plus its similarity score.
class ReferenceChunk {
  const ReferenceChunk({
    required this.id,
    required this.cardName,
    required this.orientation,
    required this.facet,
    required this.title,
    required this.text,
    required this.score,
  });

  final String id;
  final String cardName;
  final String? orientation;
  final String facet;
  final String title;
  final String text;
  final double score;

  String get label => '$cardName | ${orientation ?? 'card'}.$facet';
}
