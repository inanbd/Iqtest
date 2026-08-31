import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/data/question_bank.dart';
import 'package:iq_test/models/question.dart';
import 'package:iq_test/services/scoring.dart';

/// Builds a synthetic item of a given difficulty so scoring can be tested
/// independently of the real bank.
TextQuestion _q(String id, QuestionCategory category, int difficulty) {
  return TextQuestion(
    id: id,
    category: category,
    difficulty: difficulty,
    prompt: 'prompt',
    options: const ['a', 'b', 'c', 'd'],
    correctIndex: 0,
    explanation: 'because',
  );
}

void main() {
  group('normalCdf', () {
    test('is centred on zero', () {
      expect(Scoring.normalCdf(0), closeTo(0.5, 1e-6));
    });

    test('matches published values', () {
      expect(Scoring.normalCdf(1), closeTo(0.8413, 1e-4));
      expect(Scoring.normalCdf(-1), closeTo(0.1587, 1e-4));
      expect(Scoring.normalCdf(1.96), closeTo(0.9750, 1e-4));
      expect(Scoring.normalCdf(-2.58), closeTo(0.0049, 1e-4));
    });

    test('is symmetric', () {
      for (final z in [0.3, 1.1, 2.4, 3.0]) {
        expect(
          Scoring.normalCdf(z) + Scoring.normalCdf(-z),
          closeTo(1.0, 1e-6),
        );
      }
    });

    test('is monotonic', () {
      var previous = 0.0;
      for (var z = -3.0; z <= 3.0; z += 0.25) {
        final value = Scoring.normalCdf(z);
        expect(value, greaterThanOrEqualTo(previous));
        previous = value;
      }
    });
  });

  group('indexForProportion', () {
    test('maps the reference mean onto 100', () {
      expect(Scoring.indexForProportion(Scoring.referenceMeanProportion), 100);
    });

    test('maps one reference SD above the mean onto 115', () {
      final proportion =
          Scoring.referenceMeanProportion + Scoring.referenceSdProportion;
      expect(Scoring.indexForProportion(proportion), 115);
    });

    test('is monotonic in the proportion', () {
      var previous = 0;
      for (var p = 0.0; p <= 1.0; p += 0.02) {
        final index = Scoring.indexForProportion(p);
        expect(index, greaterThanOrEqualTo(previous));
        previous = index;
      }
    });

    test('never leaves the clamp range', () {
      for (final p in [-1.0, 0.0, 0.5, 1.0, 2.0]) {
        final index = Scoring.indexForProportion(p);
        expect(index, inInclusiveRange(Scoring.minIndex, Scoring.maxIndex));
      }
    });
  });

  group('percentileForIndex', () {
    test('puts the scale mean at the halfway point', () {
      expect(Scoring.percentileForIndex(100), closeTo(50, 0.01));
    });

    test('puts one SD above the mean near the 84th percentile', () {
      expect(Scoring.percentileForIndex(115), closeTo(84.13, 0.05));
    });

    test('stays inside the reportable range', () {
      for (var index = Scoring.minIndex; index <= Scoring.maxIndex; index++) {
        expect(Scoring.percentileForIndex(index), inInclusiveRange(0.1, 99.9));
      }
    });
  });

  group('score', () {
    final questions = [
      _q('a', QuestionCategory.numerical, 1),
      _q('b', QuestionCategory.numerical, 5),
      _q('c', QuestionCategory.verbal, 2),
      _q('d', QuestionCategory.spatial, 2),
    ];

    test('counts correct answers and weights them by difficulty', () {
      final result = Scoring.score(
        questions: questions,
        answers: const [0, 0, 1, null],
      );
      expect(result.correct, 2);
      expect(result.total, 4);
      expect(result.weightedScore, 6); // 1 + 5
      expect(result.maxWeightedScore, 10); // 1 + 5 + 2 + 2
      expect(result.weightedProportion, closeTo(0.6, 1e-9));
    });

    test('treats an unanswered item as incorrect', () {
      final result = Scoring.score(
        questions: questions,
        answers: const [null, null, null, null],
      );
      expect(result.correct, 0);
      expect(result.weightedScore, 0);
    });

    test('rewards a hard item more than an easy one', () {
      final hardOnly = Scoring.score(
        questions: questions,
        answers: const [null, 0, null, null],
      );
      final easyOnly = Scoring.score(
        questions: questions,
        answers: const [0, null, null, null],
      );
      expect(hardOnly.iq, greaterThan(easyOnly.iq));
      expect(hardOnly.correct, easyOnly.correct);
    });

    test('breaks the result down by domain', () {
      final result = Scoring.score(
        questions: questions,
        answers: const [0, 1, 0, 0],
      );
      expect(result.byCategory.keys, hasLength(3));
      expect(result.byCategory[QuestionCategory.numerical]!.total, 2);
      expect(result.byCategory[QuestionCategory.numerical]!.correct, 1);
      expect(
        result.byCategory[QuestionCategory.numerical]!.accuracy,
        closeTo(0.5, 1e-9),
      );
      expect(result.byCategory[QuestionCategory.verbal]!.correct, 1);
      expect(result.byCategory[QuestionCategory.spatial]!.correct, 1);
      // Domains the test did not sample are left out entirely.
      expect(result.byCategory.containsKey(QuestionCategory.logical), isFalse);
    });

    test('carries the elapsed time through', () {
      final result = Scoring.score(
        questions: questions,
        answers: const [0, 0, 0, 0],
        elapsed: const Duration(minutes: 7, seconds: 30),
      );
      expect(result.elapsed, const Duration(minutes: 7, seconds: 30));
    });

    test('scores a perfect and an empty full test at the scale extremes', () {
      final full = QuestionBank.fullTest();
      final perfect = Scoring.score(
        questions: full,
        answers: full.map((q) => q.correctIndex).toList(),
      );
      final blank = Scoring.score(
        questions: full,
        answers: List<int?>.filled(full.length, null),
      );

      expect(perfect.correct, full.length);
      expect(perfect.weightedProportion, closeTo(1.0, 1e-9));
      expect(perfect.iq, 136);
      expect(perfect.percentile, greaterThan(99));

      expect(blank.correct, 0);
      expect(blank.iq, 57);
      expect(blank.percentile, lessThan(1));

      expect(perfect.iq, greaterThan(blank.iq));
    });
  });

  group('bandFor', () {
    test('labels the conventional ranges', () {
      expect(Scoring.bandFor(135), 'Very superior');
      expect(Scoring.bandFor(125), 'Superior');
      expect(Scoring.bandFor(112), 'High average');
      expect(Scoring.bandFor(100), 'Average');
      expect(Scoring.bandFor(85), 'Low average');
      expect(Scoring.bandFor(72), 'Borderline');
      expect(Scoring.bandFor(60), 'Well below average');
    });

    test('covers every reportable index', () {
      for (var index = Scoring.minIndex; index <= Scoring.maxIndex; index++) {
        expect(Scoring.bandFor(index), isNotEmpty);
      }
    });
  });
}
