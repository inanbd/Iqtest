import 'question.dart';

/// A completed test, stored locally so progress can be tracked over time.
class Attempt {
  const Attempt({
    required this.takenAt,
    required this.iq,
    required this.correct,
    required this.total,
    required this.duration,
    required this.categoryAccuracy,
  });

  final DateTime takenAt;
  final int iq;
  final int correct;
  final int total;
  final Duration duration;

  /// Proportion correct (0..1) per category.
  final Map<QuestionCategory, double> categoryAccuracy;

  Map<String, dynamic> toJson() => {
    'takenAt': takenAt.toIso8601String(),
    'iq': iq,
    'correct': correct,
    'total': total,
    'durationSeconds': duration.inSeconds,
    'categoryAccuracy': {
      for (final entry in categoryAccuracy.entries) entry.key.name: entry.value,
    },
  };

  static Attempt fromJson(Map<String, dynamic> json) {
    final rawAccuracy =
        (json['categoryAccuracy'] as Map?)?.cast<String, dynamic>() ?? {};
    final accuracy = <QuestionCategory, double>{};
    for (final category in QuestionCategory.values) {
      final value = rawAccuracy[category.name];
      if (value is num) accuracy[category] = value.toDouble();
    }
    return Attempt(
      takenAt: DateTime.parse(json['takenAt'] as String),
      iq: (json['iq'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      duration: Duration(seconds: (json['durationSeconds'] as num).toInt()),
      categoryAccuracy: accuracy,
    );
  }
}
