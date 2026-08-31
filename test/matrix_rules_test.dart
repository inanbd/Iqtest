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

  // The fill alternates at every step.
  's2': (g) => FigureSpec(shape: ShapeKind.square, filled: !g[7]!.filled),

  // Every shape appears once per row and once per column.
  's3': (g) =>
      FigureSpec(shape: _theMissingOne(_shapes, [g[6]!.shape, g[7]!.shape])),

  // Shape is fixed by the column, count by the row.
  's4': (g) => FigureSpec(shape: g[2]!.shape, count: g[6]!.count),

  // The arrow turns a quarter turn clockwise at every step.
  's5': (g) => FigureSpec(
    shape: ShapeKind.arrow,
    rotationQuarters: (g[7]!.rotationQuarters + 1) % 4,
  ),

  // Every count appears once per row and once per column.
  's6': (g) => FigureSpec(
    shape: ShapeKind.circle,
    count: _theMissingOne(_counts, [g[6]!.count, g[7]!.count]),
  ),

  // The third cell holds as many shapes as the first two combined.
  's7': (g) =>
      FigureSpec(shape: ShapeKind.square, count: g[6]!.count + g[7]!.count),

  // Shape is fixed by the column, fill by the row.
  's8': (g) => FigureSpec(shape: g[2]!.shape, filled: g[6]!.filled),

  // Rotation advances across the row; fill is fixed by the row.
  's9': (g) => FigureSpec(
    shape: ShapeKind.triangle,
    rotationQuarters: (g[7]!.rotationQuarters + 1) % 4,
    filled: g[6]!.filled,
  ),

  // The count doubles across the row while the fill flips at every step.
  's10': (g) => FigureSpec(
    shape: ShapeKind.circle,
    count: g[7]!.count * 2,
    filled: !g[7]!.filled,
  ),

  // Shape and count are each a Latin square, running independently.
  's11': (g) => FigureSpec(
    shape: _theMissingOne(_shapes, [g[6]!.shape, g[7]!.shape]),
    count: _theMissingOne(_counts, [g[6]!.count, g[7]!.count]),
  ),

  // The third cell holds the first count minus the second.
  's12': (g) =>
      FigureSpec(shape: ShapeKind.square, count: g[6]!.count - g[7]!.count),

  // Shape by column, counts Latin, and a dot exactly when the count is odd.
  's13': (g) {
    final count = _theMissingOne(_counts, [g[6]!.count, g[7]!.count]);
    return FigureSpec(shape: g[2]!.shape, count: count, hasDot: count.isOdd);
  },

  // The third cell is solid when exactly one of the first two is.
  's14': (g) =>
      FigureSpec(shape: ShapeKind.circle, filled: g[6]!.filled != g[7]!.filled),

  // The third arrow is the first two turned together, wrapping at a circle.
  's15': (g) => FigureSpec(
    shape: ShapeKind.arrow,
    rotationQuarters: (g[6]!.rotationQuarters + g[7]!.rotationQuarters) % 4,
  ),

  // The shape the first two do not use, and their two counts added.
  's16': (g) => FigureSpec(
    shape: _theMissingOne(_shapes, [g[6]!.shape, g[7]!.shape]),
    count: g[6]!.count + g[7]!.count,
  ),
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
        expect(
          question.options[question.correctIndex],
          _rules[question.id]!(question.grid),
          reason: 'the key does not match what the rule produces',
        );
      });

      test('no distractor also satisfies the rule', () {
        final derived = _rules[question.id]!(question.grid);
        expect(
          [
            for (var i = 0; i < question.options.length; i++)
              if (question.options[i] == derived) i,
          ],
          [question.correctIndex],
          reason: 'exactly one option should satisfy the rule',
        );
      });

      test('the rule also holds for the two complete rows', () {
        // Rows 0 and 1 are fully given, so the same derivation applied to
        // their first two cells must reproduce their third.
        final rule = _rules[question.id]!;
        for (final row in [0, 1]) {
          final shifted = <FigureSpec?>[
            ...question.grid.sublist(0, 6),
            question.grid[row * 3],
            question.grid[row * 3 + 1],
            null,
          ];
          // Only the row-local rules can be checked this way; rules that read
          // a fixed cell (a column's shape, say) are covered by the grid
          // checks below instead.
          if (const {
            's3',
            's5',
            's6',
            's7',
            's9',
            's10',
            's11',
            's12',
            's14',
            's15',
            's16',
            's2',
          }.contains(question.id)) {
            expect(
              rule(shifted),
              question.grid[row * 3 + 2],
              reason: 'row $row of ${question.id} breaks its own rule',
            );
          }
        }
      });
    });
  }

  group('grids obey their own rules throughout', () {
    /// The nine cells with the answer filled in.
    List<FigureSpec> completed(String id) {
      final question = matrices.firstWhere((q) => q.id == id);
      return [
        ...question.grid.sublist(0, 8).map((cell) => cell!),
        question.options[question.correctIndex],
      ];
    }

    test('s3, s6 and s11 are Latin squares', () {
      final keys = <String, Object Function(FigureSpec)>{
        's3': (f) => f.shape,
        's6': (f) => f.count,
        's11': (f) => f.shape,
      };
      for (final entry in keys.entries) {
        final grid = completed(entry.key);
        for (var i = 0; i < 3; i++) {
          expect(
            {for (var c = 0; c < 3; c++) entry.value(grid[i * 3 + c])},
            hasLength(3),
            reason: '${entry.key} row $i repeats',
          );
          expect(
            {for (var r = 0; r < 3; r++) entry.value(grid[r * 3 + i])},
            hasLength(3),
            reason: '${entry.key} column $i repeats',
          );
        }
      }
    });

    test('s11 is a Latin square in its counts as well as its shapes', () {
      final grid = completed('s11');
      for (var i = 0; i < 3; i++) {
        expect(
          {for (var c = 0; c < 3; c++) grid[i * 3 + c].count},
          hasLength(3),
          reason: 'row $i repeats a count',
        );
        expect(
          {for (var r = 0; r < 3; r++) grid[r * 3 + i].count},
          hasLength(3),
          reason: 'column $i repeats a count',
        );
      }
    });

    test('s1 and s4 hold their row and column rules everywhere', () {
      final s1 = completed('s1');
      final s4 = completed('s4');
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          expect(s1[r * 3 + c].shape, s1[r * 3].shape, reason: 's1 shape');
          expect(s1[r * 3 + c].count, s1[c].count, reason: 's1 count');
          expect(s4[r * 3 + c].shape, s4[c].shape, reason: 's4 shape');
          expect(s4[r * 3 + c].count, s4[r * 3].count, reason: 's4 count');
        }
      }
    });

    test('s8 holds shape by column and fill by row', () {
      final grid = completed('s8');
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          expect(grid[r * 3 + c].shape, grid[c].shape);
          expect(grid[r * 3 + c].filled, grid[r * 3].filled);
        }
      }
    });

    test('s13 shows a dot exactly on the odd counts', () {
      for (final figure in completed('s13')) {
        expect(figure.hasDot, figure.count.isOdd);
      }
    });

    test('every completed grid uses a valid count', () {
      for (final question in matrices) {
        for (final figure in completed(question.id)) {
          expect(figure.count, inInclusiveRange(1, 4), reason: question.id);
        }
      }
    });
  });
}
