import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/data/question_bank.dart';
import 'package:iq_test/models/figure_spec.dart';
import 'package:iq_test/models/question.dart';

/// Re-derives the answer to each matrix item from the rule its explanation
/// claims, independently of the authored `correctIndex`.
///
/// An authoring slip — a distractor that also satisfies the rule, or a key
/// pointing at the wrong option — fails here rather than in front of a
/// candidate.
typedef Derivation = FigureSpec Function(List<FigureSpec?> grid);

/// The member of [values] that does not appear among [seen].
T _theMissingOne<T>(Set<T> values, Iterable<T> seen) {
  final remaining = values.difference(seen.toSet());
  expect(remaining, hasLength(1), reason: 'rule should leave one candidate');
  return remaining.single;
}

const _shapes = {ShapeKind.circle, ShapeKind.square, ShapeKind.triangle};
const _counts = {1, 2, 3};

final Map<String, Derivation> _rules = {
  // Shape is fixed by the row, count by the column.
  's1': (g) => FigureSpec(shape: g[6]!.shape, count: g[2]!.count),

  // Every shape appears once per row and once per column.
  's2': (g) =>
      FigureSpec(shape: _theMissingOne(_shapes, [g[6]!.shape, g[7]!.shape])),

  // The arrow turns a quarter turn clockwise at every step.
  's3': (g) => FigureSpec(
    shape: ShapeKind.arrow,
    rotationQuarters: (g[7]!.rotationQuarters + 1) % 4,
  ),

  // Every count appears once per row and once per column.
  's4': (g) => FigureSpec(
    shape: ShapeKind.circle,
    count: _theMissingOne(_counts, [g[6]!.count, g[7]!.count]),
  ),

  // The third cell in a row holds as many shapes as the first two combined.
  's5': (g) =>
      FigureSpec(shape: ShapeKind.square, count: g[6]!.count + g[7]!.count),

  // Rotation advances across the row; fill is fixed by the row.
  's6': (g) => FigureSpec(
    shape: ShapeKind.triangle,
    rotationQuarters: (g[7]!.rotationQuarters + 1) % 4,
    filled: g[6]!.filled,
  ),

  // The count doubles across the row while the fill flips at every step.
  's7': (g) => FigureSpec(
    shape: ShapeKind.circle,
    count: g[7]!.count * 2,
    filled: !g[7]!.filled,
  ),

  // Shape by column, counts Latin, and a dot exactly when the count is odd.
  's8': (g) {
    final count = _theMissingOne(_counts, [g[6]!.count, g[7]!.count]);
    return FigureSpec(shape: g[2]!.shape, count: count, hasDot: count.isOdd);
  },
};

void main() {
  final matrices = QuestionBank.all.whereType<MatrixQuestion>().toList();

  test('every matrix item has a rule encoded here', () {
    expect(
      matrices.map((q) => q.id).toSet(),
      _rules.keys.toSet(),
      reason: 'a new matrix item needs its rule added to this test',
    );
  });

  for (final question in matrices) {
    group('item ${question.id}', () {
      test('the blank is the bottom-right cell', () {
        expect(question.missingIndex, 8);
      });

      test('the rule derives the authored answer', () {
        final derived = _rules[question.id]!(question.grid);
        expect(
          question.options[question.correctIndex],
          derived,
          reason: 'the key does not match what the rule produces',
        );
      });

      test('no distractor also satisfies the rule', () {
        final derived = _rules[question.id]!(question.grid);
        final satisfying = <int>[
          for (var i = 0; i < question.options.length; i++)
            if (question.options[i] == derived) i,
        ];
        expect(satisfying, [
          question.correctIndex,
        ], reason: 'exactly one option should satisfy the rule');
      });
    });
  }

  group('grids obey their own rules throughout', () {
    test('s2 and s4 are Latin squares', () {
      for (final id in ['s2', 's4']) {
        final question = matrices.firstWhere((q) => q.id == id);
        final grid = [
          ...question.grid.sublist(0, 8),
          question.options[question.correctIndex],
        ];
        // Read the varying attribute: shape for s2, count for s4.
        final key = id == 's2'
            ? (FigureSpec f) => f.shape as Object
            : (FigureSpec f) => f.count as Object;
        for (var i = 0; i < 3; i++) {
          final row = [for (var c = 0; c < 3; c++) key(grid[i * 3 + c]!)];
          final column = [for (var r = 0; r < 3; r++) key(grid[r * 3 + i]!)];
          expect(row.toSet(), hasLength(3), reason: '$id row $i repeats');
          expect(column.toSet(), hasLength(3), reason: '$id column $i repeats');
        }
      }
    });

    test('s5 holds the sum rule in every completed row', () {
      final question = matrices.firstWhere((q) => q.id == 's5');
      final grid = [
        ...question.grid.sublist(0, 8),
        question.options[question.correctIndex],
      ];
      for (var row = 0; row < 3; row++) {
        expect(
          grid[row * 3 + 2]!.count,
          grid[row * 3]!.count + grid[row * 3 + 1]!.count,
          reason: 'row $row breaks the sum rule',
        );
      }
    });

    test('s8 shows a dot exactly on the odd counts', () {
      final question = matrices.firstWhere((q) => q.id == 's8');
      final grid = [
        ...question.grid.sublist(0, 8),
        question.options[question.correctIndex],
      ];
      for (var i = 0; i < 9; i++) {
        expect(
          grid[i]!.hasDot,
          grid[i]!.count.isOdd,
          reason: 'cell $i breaks the dot rule',
        );
      }
    });
  });
}
