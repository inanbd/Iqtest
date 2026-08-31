import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/data/question_bank.dart';
import 'package:iq_test/data/test_blueprint.dart';
import 'package:iq_test/models/question.dart';

const _blueprints = {'full': TestBlueprint.full, 'quick': TestBlueprint.quick};

/// How many items a draw took from one (domain, difficulty) cell.
Map<(QuestionCategory, int), int> _profileOf(List<Question> test) {
  final profile = <(QuestionCategory, int), int>{};
  for (final question in test) {
    profile.update(
      (question.category, question.difficulty),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  return profile;
}

int _weightOf(List<Question> test) =>
    test.fold(0, (sum, q) => sum + q.difficulty);

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
      }
    });

    test('matrix options are distinct from one another', () {
      for (final question in QuestionBank.all.whereType<MatrixQuestion>()) {
        expect(
          question.options.toSet(),
          hasLength(question.options.length),
          reason: 'item ${question.id} repeats an option',
        );
      }
    });

    test('every domain is represented', () {
      for (final category in QuestionCategory.values) {
        expect(
          QuestionBank.byCategory(category),
          isNotEmpty,
          reason: category.name,
        );
      }
    });
  });

  group('the pool can serve the blueprints', () {
    test('every cell holds at least what a sitting draws from it', () {
      for (final entry in _blueprints.entries) {
        for (final category in QuestionCategory.values) {
          for (final cell in entry.value.perDifficulty.entries) {
            expect(
              QuestionBank.cell(category, cell.key).length,
              greaterThanOrEqualTo(cell.value),
              reason:
                  'the ${entry.key} sitting draws ${cell.value} '
                  '${category.name} items at difficulty ${cell.key}, '
                  'but the pool cannot supply them',
            );
          }
        }
      }
    });

    test('every cell holds twice what a sitting draws, so repeats can be '
        'avoided in full', () {
      for (final entry in _blueprints.entries) {
        for (final category in QuestionCategory.values) {
          for (final cell in entry.value.perDifficulty.entries) {
            expect(
              QuestionBank.cell(category, cell.key).length,
              greaterThanOrEqualTo(entry.value.poolNeededFor(cell.key)),
              reason:
                  'a second ${entry.key} sitting could not avoid the first '
                  'for ${category.name} at difficulty ${cell.key}',
            );
          }
        }
      }
    });
  });

  group('draw', () {
    test('hits the blueprint exactly, whatever the seed', () {
      for (final entry in _blueprints.entries) {
        final blueprint = entry.value;
        for (var seed = 0; seed < 20; seed++) {
          final test = QuestionBank.draw(
            blueprint: blueprint,
            random: Random(seed),
          );
          final profile = _profileOf(test);
          for (final category in QuestionCategory.values) {
            for (var difficulty = 1; difficulty <= 5; difficulty++) {
              expect(
                profile[(category, difficulty)] ?? 0,
                blueprint.perDifficulty[difficulty] ?? 0,
                reason:
                    '${entry.key} seed $seed: wrong number of '
                    '${category.name} items at difficulty $difficulty',
              );
            }
          }
        }
      }
    });

    test('offers the same points every sitting, which is what makes two '
        'scores comparable', () {
      for (final entry in _blueprints.entries) {
        final expected = entry.value.maxWeight(QuestionCategory.values.length);
        for (var seed = 0; seed < 20; seed++) {
          final test = QuestionBank.draw(
            blueprint: entry.value,
            random: Random(seed),
          );
          expect(_weightOf(test), expected, reason: '${entry.key} seed $seed');
        }
      }
    });

    test('never repeats an item within one sitting', () {
      for (var seed = 0; seed < 20; seed++) {
        final test = QuestionBank.fullTest(random: Random(seed));
        expect(test.map((q) => q.id).toSet(), hasLength(test.length));
      }
    });

    test('ramps from easiest to hardest', () {
      for (final blueprint in _blueprints.values) {
        final test = QuestionBank.draw(blueprint: blueprint, random: Random(7));
        for (var i = 1; i < test.length; i++) {
          expect(
            test[i].difficulty,
            greaterThanOrEqualTo(test[i - 1].difficulty),
          );
        }
      }
    });

    test('draws a different set of items from one sitting to the next', () {
      final a = QuestionBank.fullTest(random: Random(1)).map((q) => q.id);
      final b = QuestionBank.fullTest(random: Random(2)).map((q) => q.id);
      expect(a.toSet(), isNot(b.toSet()));
    });

    test('the full and quick sittings are the advertised size', () {
      expect(QuestionBank.fullTest(random: Random(0)), hasLength(32));
      expect(QuestionBank.quickTest(random: Random(0)), hasLength(16));
    });
  });

  group('avoiding what was seen last time', () {
    test('two consecutive sittings share no items at all', () {
      for (final entry in _blueprints.entries) {
        for (var seed = 0; seed < 30; seed++) {
          final first = QuestionBank.draw(
            blueprint: entry.value,
            random: Random(seed),
          );
          final second = QuestionBank.draw(
            blueprint: entry.value,
            avoid: first.map((q) => q.id).toSet(),
            random: Random(seed + 500),
          );
          expect(
            second
                .map((q) => q.id)
                .toSet()
                .intersection(first.map((q) => q.id).toSet()),
            isEmpty,
            reason: '${entry.key} seed $seed repeated an item',
          );
        }
      }
    });

    test('a mixed pair of formats also comes back fresh', () {
      final full = QuestionBank.fullTest(random: Random(3));
      final quick = QuestionBank.quickTest(
        avoid: full.map((q) => q.id).toSet(),
        random: Random(4),
      );
      expect(
        quick
            .map((q) => q.id)
            .toSet()
            .intersection(full.map((q) => q.id).toSet()),
        isEmpty,
      );
      expect(quick, hasLength(16));
    });

    test('still fills the blueprint when everything is excluded', () {
      // The pool cannot honour this, so the draw must fall back to seen items
      // rather than returning a short test.
      final everything = QuestionBank.all.map((q) => q.id).toSet();
      final test = QuestionBank.fullTest(avoid: everything, random: Random(11));
      expect(test, hasLength(32));
      expect(
        _weightOf(test),
        TestBlueprint.full.maxWeight(QuestionCategory.values.length),
      );
      expect(test.map((q) => q.id).toSet(), hasLength(32));
    });
  });

  group('TestBlueprint', () {
    test('reports its own totals', () {
      expect(TestBlueprint.full.itemsPerCategory, 8);
      expect(TestBlueprint.full.weightPerCategory, 27);
      expect(TestBlueprint.full.itemCount(4), 32);
      expect(TestBlueprint.full.maxWeight(4), 108);

      expect(TestBlueprint.quick.itemsPerCategory, 4);
      expect(TestBlueprint.quick.weightPerCategory, 14);
      expect(TestBlueprint.quick.itemCount(4), 16);
      expect(TestBlueprint.quick.maxWeight(4), 56);
    });

    test('asks for twice what it draws', () {
      expect(TestBlueprint.full.poolNeededFor(3), 4);
      expect(TestBlueprint.full.poolNeededFor(1), 2);
      expect(TestBlueprint.quick.poolNeededFor(1), 0);
    });
  });
}
