import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/data/question_bank.dart';
import 'package:iq_test/models/question.dart';

void main() {
  group('item integrity', () {
    test('every id is unique', () {
      final ids = QuestionBank.all.map((q) => q.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every item is well formed', () {
      for (final question in QuestionBank.all) {
        final where = 'item ${question.id}';
        expect(question.prompt, isNotEmpty, reason: where);
        expect(question.explanation, isNotEmpty, reason: where);
        expect(question.difficulty, inInclusiveRange(1, 5), reason: where);
        expect(question.optionCount, 4, reason: where);
        expect(
          question.correctIndex,
          inInclusiveRange(0, question.optionCount - 1),
          reason: where,
        );
      }
    });

    test('text options are distinct and non-empty', () {
      for (final question in QuestionBank.all.whereType<TextQuestion>()) {
        expect(question.options.toSet(), hasLength(4), reason: question.id);
        for (final option in question.options) {
          expect(option.trim(), isNotEmpty, reason: question.id);
        }
      }
    });

    test('matrix items have a nine-cell grid with exactly one blank', () {
      final matrices = QuestionBank.all.whereType<MatrixQuestion>();
      expect(matrices, isNotEmpty);
      for (final question in matrices) {
        expect(question.grid, hasLength(9), reason: question.id);
        expect(
          question.grid.where((cell) => cell == null),
          hasLength(1),
          reason: question.id,
        );
        expect(question.missingIndex, isNonNegative, reason: question.id);
      }
    });

    test('matrix distractors are distinct from each other and the answer', () {
      for (final question in QuestionBank.all.whereType<MatrixQuestion>()) {
        expect(
          question.options.toSet(),
          hasLength(question.options.length),
          reason: 'item ${question.id} repeats an option',
        );
      }
    });

    test('each domain contributes eight items', () {
      for (final category in QuestionCategory.values) {
        expect(
          QuestionBank.byCategory(category),
          hasLength(8),
          reason: category.name,
        );
      }
      expect(QuestionBank.all, hasLength(32));
    });

    test('each domain spans a range of difficulties', () {
      for (final category in QuestionCategory.values) {
        final difficulties = QuestionBank.byCategory(
          category,
        ).map((q) => q.difficulty);
        expect(
          difficulties.reduce(min),
          lessThanOrEqualTo(2),
          reason: '${category.name} has no easy items',
        );
        expect(
          difficulties.reduce(max),
          greaterThanOrEqualTo(4),
          reason: '${category.name} has no hard items',
        );
      }
    });
  });

  group('fullTest', () {
    test('presents the whole bank', () {
      final test = QuestionBank.fullTest(random: Random(1));
      expect(test, hasLength(QuestionBank.all.length));
      expect(
        test.map((q) => q.id).toSet(),
        QuestionBank.all.map((q) => q.id).toSet(),
      );
    });

    test('ramps from easiest to hardest', () {
      final test = QuestionBank.fullTest(random: Random(7));
      for (var i = 1; i < test.length; i++) {
        expect(
          test[i].difficulty,
          greaterThanOrEqualTo(test[i - 1].difficulty),
        );
      }
    });

    test('varies the order between sittings', () {
      final a = QuestionBank.fullTest(random: Random(1)).map((q) => q.id);
      final b = QuestionBank.fullTest(random: Random(2)).map((q) => q.id);
      expect(a, isNot(orderedEquals(b.toList())));
    });
  });

  group('quickTest', () {
    test('draws a balanced, duplicate-free short form', () {
      for (var seed = 0; seed < 25; seed++) {
        final test = QuestionBank.quickTest(random: Random(seed));
        expect(test, hasLength(16), reason: 'seed $seed');
        expect(
          test.map((q) => q.id).toSet(),
          hasLength(16),
          reason: 'seed $seed repeats an item',
        );
        for (final category in QuestionCategory.values) {
          expect(
            test.where((q) => q.category == category),
            hasLength(4),
            reason: 'seed $seed is unbalanced for ${category.name}',
          );
        }
      }
    });

    test('still ramps from easiest to hardest', () {
      final test = QuestionBank.quickTest(random: Random(3));
      for (var i = 1; i < test.length; i++) {
        expect(
          test[i].difficulty,
          greaterThanOrEqualTo(test[i - 1].difficulty),
        );
      }
    });

    test('spans easy and hard items rather than clustering', () {
      for (var seed = 0; seed < 25; seed++) {
        final test = QuestionBank.quickTest(random: Random(seed));
        final difficulties = test.map((q) => q.difficulty);
        expect(
          difficulties.reduce(min),
          lessThanOrEqualTo(2),
          reason: 'seed $seed',
        );
        expect(
          difficulties.reduce(max),
          greaterThanOrEqualTo(4),
          reason: 'seed $seed',
        );
      }
    });

    test('honours a smaller draw', () {
      final test = QuestionBank.quickTest(perCategory: 2, random: Random(9));
      expect(test, hasLength(8));
      for (final category in QuestionCategory.values) {
        expect(test.where((q) => q.category == category), hasLength(2));
      }
    });
  });
}
