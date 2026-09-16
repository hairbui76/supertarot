/// A single study prompt: which card was drawn and which facet is being asked.
class StudyDraw {
  const StudyDraw({
    required this.cardName,
    required this.imageFile,
    required this.facet,
    required this.facetLabel,
    required this.question,
    required this.hint,
    required this.cycle,
    required this.remainingInCycle,
    required this.language,
    required this.createdAt,
  });

  factory StudyDraw.fromJson(Map<String, dynamic> json) => StudyDraw(
        cardName: json['card_name'] as String,
        imageFile: json['card_image'] as String? ?? '',
        facet: json['facet'] as String,
        facetLabel: json['facet_label'] as String,
        question: json['question'] as String,
        hint: json['hint'] as String,
        cycle: json['cycle'] as int? ?? 1,
        remainingInCycle: json['remaining_in_cycle'] as int? ?? 0,
        language: json['language'] as String? ?? 'vi',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
      );

  final String cardName;
  final String imageFile;
  final String facet;
  final String facetLabel;
  final String question;
  final String hint;
  final int cycle;
  final int remainingInCycle;
  final String language;
  final DateTime createdAt;

  String get assetPath => 'assets/images/$imageFile';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'card_name': cardName,
        'card_image': imageFile,
        'facet': facet,
        'facet_label': facetLabel,
        'question': question,
        'hint': hint,
        'cycle': cycle,
        'remaining_in_cycle': remainingInCycle,
        'language': language,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Result of grading an answer, matching the JSON schema the bot's rubric
/// prompt asks the model to return.
class GradeResult {
  const GradeResult({
    required this.score,
    required this.passed,
    required this.correctPoints,
    required this.missingPoints,
    required this.incorrectPoints,
    required this.feedback,
    required this.nextHint,
  });

  factory GradeResult.fromJson(Map<String, dynamic> json) => GradeResult(
        score: (json['score'] as num?)?.round() ?? 0,
        passed: json['passed'] as bool? ?? false,
        correctPoints: _points(json['correct_points']),
        missingPoints: _points(json['missing_points']),
        incorrectPoints: _points(json['incorrect_points']),
        feedback: json['feedback'] as String? ?? '',
        nextHint: json['next_hint'] as String? ?? '',
      );

  final int score;
  final bool passed;
  final List<String> correctPoints;
  final List<String> missingPoints;
  final List<String> incorrectPoints;
  final String feedback;
  final String nextHint;

  static List<String> _points(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
