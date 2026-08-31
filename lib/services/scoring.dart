import 'dart:math' as math;

import '../models/question.dart';

/// Per-domain breakdown of a completed test.
class CategoryScore {
  const CategoryScore({
    required this.category,
    required this.correct,
    required this.total,
  });

  final QuestionCategory category;
  final int correct;
  final int total;

  /// Proportion correct, 0..1. Zero when the domain was not sampled.
  double get accuracy => total == 0 ? 0 : correct / total;
}

/// The outcome of a completed test.
class ScoreResult {
  const ScoreResult({
    required this.correct,
    required this.total,
    required this.weightedScore,
    required this.maxWeightedScore,
    required this.iq,
    required this.percentile,
    required this.byCategory,
    required this.elapsed,
  });

  /// Items answered correctly.
  final int correct;

  /// Items presented.
  final int total;

  /// Difficulty-weighted points earned.
  final double weightedScore;

  /// Difficulty-weighted points available.
  final double maxWeightedScore;

  /// Deviation-scale index, mean 100 and standard deviation 15.
  final int iq;

  /// Percentage of the reference distribution scoring at or below [iq].
  final double percentile;

  final Map<QuestionCategory, CategoryScore> byCategory;

  /// Time spent on the test.
  final Duration elapsed;

  /// Proportion of the available weighted points earned, 0..1.
  double get weightedProportion =>
      maxWeightedScore == 0 ? 0 : weightedScore / maxWeightedScore;

  String get band => Scoring.bandFor(iq);
}

/// Turns raw answers into a deviation-scale index.
///
/// Items are weighted by difficulty, so a hard item is worth more than an
/// easy one. The resulting proportion is mapped onto the conventional
/// deviation scale (mean 100, standard deviation 15) using the reference
/// constants below, then clamped to the range the item pool can actually
/// discriminate over.
///
/// Those constants are assumed, not measured: this app has no norming sample,
/// so the index is a self-consistent scale for comparing your own attempts,
/// not a clinical measurement.
abstract final class Scoring {
  /// Assumed mean weighted proportion in the reference population.
  static const double referenceMeanProportion = 0.55;

  /// Assumed standard deviation of that proportion.
  static const double referenceSdProportion = 0.19;

  /// Scale mean and standard deviation of the deviation index.
  static const double scaleMean = 100;
  static const double scaleSd = 15;

  /// The index is clamped here: a 32-item test cannot resolve the tails.
  static const int minIndex = 55;
  static const int maxIndex = 145;

  static ScoreResult score({
    required List<Question> questions,
    required List<int?> answers,
    Duration elapsed = Duration.zero,
  }) {
    assert(
      questions.length == answers.length,
      'answers must line up with questions',
    );

    var correct = 0;
    var weighted = 0.0;
    var maxWeighted = 0.0;
    final correctPerCategory = <QuestionCategory, int>{};
    final totalPerCategory = <QuestionCategory, int>{};

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final weight = question.difficulty.toDouble();
      maxWeighted += weight;
      totalPerCategory.update(
        question.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (answers[i] == question.correctIndex) {
        correct++;
        weighted += weight;
        correctPerCategory.update(
          question.category,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final proportion = maxWeighted == 0 ? 0.0 : weighted / maxWeighted;
    final index = indexForProportion(proportion);

    final byCategory = <QuestionCategory, CategoryScore>{};
    for (final category in QuestionCategory.values) {
      final total = totalPerCategory[category] ?? 0;
      if (total == 0) continue;
      byCategory[category] = CategoryScore(
        category: category,
        correct: correctPerCategory[category] ?? 0,
        total: total,
      );
    }

    return ScoreResult(
      correct: correct,
      total: questions.length,
      weightedScore: weighted,
      maxWeightedScore: maxWeighted,
      iq: index,
      percentile: percentileForIndex(index),
      byCategory: byCategory,
      elapsed: elapsed,
    );
  }

  /// Maps a weighted proportion (0..1) onto the clamped deviation scale.
  static int indexForProportion(double proportion) {
    final z = (proportion - referenceMeanProportion) / referenceSdProportion;
    final raw = scaleMean + scaleSd * z;
    return raw.round().clamp(minIndex, maxIndex);
  }

  /// Share of the reference distribution at or below [index], as a percentage.
  static double percentileForIndex(int index) {
    final z = (index - scaleMean) / scaleSd;
    return (normalCdf(z) * 100).clamp(0.1, 99.9);
  }

  /// Standard normal cumulative distribution function.
  static double normalCdf(double z) => 0.5 * (1 + _erf(z / math.sqrt2));

  /// Standard normal probability density, used to draw the reference curve.
  static double normalPdf(double z) =>
      math.exp(-0.5 * z * z) / math.sqrt(2 * math.pi);

  /// Abramowitz and Stegun 7.1.26; absolute error below 1.5e-7.
  static double _erf(double x) {
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;

    final sign = x < 0 ? -1.0 : 1.0;
    final absX = x.abs();
    final t = 1.0 / (1.0 + p * absX);
    final y =
        1.0 -
        ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) *
            t *
            math.exp(-absX * absX);
    return sign * y;
  }

  /// Conventional descriptive label for a deviation-scale index.
  static String bandFor(int index) {
    if (index >= 130) return 'Very superior';
    if (index >= 120) return 'Superior';
    if (index >= 110) return 'High average';
    if (index >= 90) return 'Average';
    if (index >= 80) return 'Low average';
    if (index >= 70) return 'Borderline';
    return 'Well below average';
  }
}
