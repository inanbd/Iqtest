import 'dart:math';

import '../models/figure_spec.dart';
import '../models/question.dart';

/// Shorthand used only while authoring the matrix items below.
FigureSpec _f(
  ShapeKind shape, {
  int count = 1,
  bool filled = false,
  int rot = 0,
  bool dot = false,
}) => FigureSpec(
  shape: shape,
  count: count,
  filled: filled,
  rotationQuarters: rot,
  hasDot: dot,
);

/// The full item pool: eight items in each of the four reasoning domains,
/// spanning difficulty 1 (easiest) to 5 (hardest).
abstract final class QuestionBank {
  static final List<Question> all = [
    ..._numerical,
    ..._verbal,
    ..._logical,
    ..._spatial,
  ];

  static List<Question> byCategory(QuestionCategory category) =>
      all.where((q) => q.category == category).toList(growable: false);

  /// The complete 32-item test, ordered easiest to hardest with categories
  /// interleaved inside each difficulty band.
  static List<Question> fullTest({Random? random}) =>
      _orderByDifficulty(all, random ?? Random());

  /// A balanced short form: [perCategory] items drawn from each domain, again
  /// ordered easiest to hardest.
  ///
  /// Within a domain the draw is stratified by difficulty so a short test
  /// still spans the easy-to-hard range instead of clustering by chance.
  static List<Question> quickTest({int perCategory = 4, Random? random}) {
    final rng = random ?? Random();
    final picked = <Question>[];
    for (final category in QuestionCategory.values) {
      final pool = byCategory(category)..shuffle(rng);
      pool.sort((a, b) => a.difficulty.compareTo(b.difficulty));
      final take = min(perCategory, pool.length);
      for (var i = 0; i < take; i++) {
        // Sample evenly across the difficulty-sorted pool.
        picked.add(pool[(i * pool.length) ~/ take]);
      }
    }
    return _orderByDifficulty(picked, rng);
  }

  static List<Question> _orderByDifficulty(
    List<Question> questions,
    Random rng,
  ) {
    final shuffled = [...questions]..shuffle(rng);
    shuffled.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return List.unmodifiable(shuffled);
  }

  // ---------------------------------------------------------------- numerical

  static const List<Question> _numerical = [
    TextQuestion(
      id: 'n1',
      category: QuestionCategory.numerical,
      difficulty: 1,
      prompt: 'Which number continues the series?',
      stimulus: '3, 6, 12, 24, ?',
      options: ['30', '36', '48', '60'],
      correctIndex: 2,
      explanation: 'Each term doubles the one before it, so 24 x 2 = 48.',
    ),
    TextQuestion(
      id: 'n2',
      category: QuestionCategory.numerical,
      difficulty: 1,
      prompt: 'Which number continues the series?',
      stimulus: '64, 32, 16, 8, ?',
      options: ['0', '2', '4', '6'],
      correctIndex: 2,
      explanation: 'Each term is half the one before it, so 8 / 2 = 4.',
    ),
    TextQuestion(
      id: 'n3',
      category: QuestionCategory.numerical,
      difficulty: 2,
      prompt: 'Which number continues the series?',
      stimulus: '1, 1, 2, 3, 5, 8, ?',
      options: ['11', '12', '13', '15'],
      correctIndex: 2,
      explanation:
          'This is the Fibonacci sequence: each term is the sum of the two '
          'before it, so 5 + 8 = 13.',
    ),
    TextQuestion(
      id: 'n4',
      category: QuestionCategory.numerical,
      difficulty: 3,
      prompt: 'Which number continues the series?',
      stimulus: '7, 10, 8, 11, 9, ?',
      options: ['7', '10', '12', '13'],
      correctIndex: 2,
      explanation:
          'The series alternates +3 and -2: 7 +3 10 -2 8 +3 11 -2 9, and the '
          'next step is +3, giving 12.',
    ),
    TextQuestion(
      id: 'n5',
      category: QuestionCategory.numerical,
      difficulty: 3,
      prompt: 'Which number continues the series?',
      stimulus: '2, 5, 10, 17, 26, ?',
      options: ['35', '36', '37', '38'],
      correctIndex: 2,
      explanation:
          'The terms are n squared plus 1 for n = 1, 2, 3...; equivalently the '
          'gaps grow 3, 5, 7, 9, 11. So 26 + 11 = 37.',
    ),
    TextQuestion(
      id: 'n6',
      category: QuestionCategory.numerical,
      difficulty: 3,
      prompt: 'Which number continues the series?',
      stimulus: '4, 9, 19, 39, ?',
      options: ['59', '69', '78', '79'],
      correctIndex: 3,
      explanation:
          'Each term is double the previous term plus 1: '
          '39 x 2 + 1 = 79.',
    ),
    TextQuestion(
      id: 'n7',
      category: QuestionCategory.numerical,
      difficulty: 4,
      prompt: 'Which number continues the series?',
      stimulus: '1, 2, 6, 24, 120, ?',
      options: ['240', '360', '600', '720'],
      correctIndex: 3,
      explanation:
          'Each term is multiplied by the next whole number: x2, x3, x4, x5, '
          'then x6. So 120 x 6 = 720.',
    ),
    TextQuestion(
      id: 'n8',
      category: QuestionCategory.numerical,
      difficulty: 4,
      prompt:
          'A bat and a ball cost 1.10 in total. The bat costs 1.00 more '
          'than the ball. How much does the ball cost?',
      options: ['0.01', '0.05', '0.10', '1.00'],
      correctIndex: 1,
      explanation:
          'If the ball costs x, the bat costs x + 1.00 and the pair costs '
          '2x + 1.00 = 1.10, so x = 0.05. The intuitive answer of 0.10 would '
          'make the total 1.20.',
    ),
  ];

  // ------------------------------------------------------------------- verbal

  static const List<Question> _verbal = [
    TextQuestion(
      id: 'v1',
      category: QuestionCategory.verbal,
      difficulty: 1,
      prompt: 'Bird is to Nest as Bee is to ?',
      options: ['Honey', 'Hive', 'Flower', 'Swarm'],
      correctIndex: 1,
      explanation:
          'A nest is the structure a bird lives in; a hive is the structure a '
          'bee lives in. Honey is a product, not a dwelling.',
    ),
    TextQuestion(
      id: 'v2',
      category: QuestionCategory.verbal,
      difficulty: 1,
      prompt: 'Which word does not belong with the others?',
      options: ['Apple', 'Banana', 'Carrot', 'Grape'],
      correctIndex: 2,
      explanation:
          'Apple, banana and grape are fruits; a carrot is a root vegetable.',
    ),
    TextQuestion(
      id: 'v3',
      category: QuestionCategory.verbal,
      difficulty: 2,
      prompt: 'Doctor is to Patient as Lawyer is to ?',
      options: ['Judge', 'Client', 'Courtroom', 'Contract'],
      correctIndex: 1,
      explanation:
          'The relation is professional to the person they serve. A doctor '
          'serves a patient; a lawyer serves a client.',
    ),
    TextQuestion(
      id: 'v4',
      category: QuestionCategory.verbal,
      difficulty: 2,
      prompt: 'Which word does not belong with the others?',
      options: ['Square', 'Triangle', 'Circle', 'Cube'],
      correctIndex: 3,
      explanation:
          'Square, triangle and circle are two-dimensional shapes; a cube is a '
          'three-dimensional solid.',
    ),
    TextQuestion(
      id: 'v5',
      category: QuestionCategory.verbal,
      difficulty: 2,
      prompt: 'Symphony is to Composer as Novel is to ?',
      options: ['Reader', 'Publisher', 'Novelist', 'Library'],
      correctIndex: 2,
      explanation:
          'The relation is work to its creator. A composer writes a symphony; '
          'a novelist writes a novel.',
    ),
    TextQuestion(
      id: 'v6',
      category: QuestionCategory.verbal,
      difficulty: 3,
      prompt: 'Whisper is to Shout as Trickle is to ?',
      options: ['Drip', 'Puddle', 'Torrent', 'Stream'],
      correctIndex: 2,
      explanation:
          'The relation is least intense to most intense form of the same '
          'thing. A shout is an intense sound; a torrent is an intense flow.',
    ),
    TextQuestion(
      id: 'v7',
      category: QuestionCategory.verbal,
      difficulty: 3,
      prompt: 'Which word does not belong with the others?',
      options: ['Sonnet', 'Haiku', 'Limerick', 'Paragraph'],
      correctIndex: 3,
      explanation:
          'A sonnet, haiku and limerick are fixed poetic forms; a paragraph is '
          'a unit of prose with no set form.',
    ),
    TextQuestion(
      id: 'v8',
      category: QuestionCategory.verbal,
      difficulty: 4,
      prompt: 'Cartographer is to Map as Choreographer is to ?',
      options: ['Music', 'Dance', 'Costume', 'Theatre'],
      correctIndex: 1,
      explanation:
          'The relation is specialist to the thing they design. A '
          'cartographer designs maps; a choreographer designs dances.',
    ),
  ];

  // ------------------------------------------------------------------ logical

  static const List<Question> _logical = [
    TextQuestion(
      id: 'l1',
      category: QuestionCategory.logical,
      difficulty: 1,
      prompt: 'Who is the shortest?',
      stimulus: 'Tom is taller than Sam.\nSam is taller than Ana.',
      options: ['Tom', 'Sam', 'Ana', 'Cannot be determined'],
      correctIndex: 2,
      explanation: 'Height order is Tom > Sam > Ana, so Ana is the shortest.',
    ),
    TextQuestion(
      id: 'l2',
      category: QuestionCategory.logical,
      difficulty: 1,
      prompt: 'Which statement must be true?',
      stimulus:
          'Every student in the class passed the exam.\n'
          'Maria is a student in the class.',
      options: [
        'Maria passed the exam',
        'Maria studied hard',
        'Maria had the highest mark',
        'Maria may have failed',
      ],
      correctIndex: 0,
      explanation:
          'The conclusion follows directly: what holds for every student in '
          'the class holds for Maria. Nothing is said about effort or rank.',
    ),
    TextQuestion(
      id: 'l3',
      category: QuestionCategory.logical,
      difficulty: 2,
      prompt: 'Which statement must be true?',
      stimulus:
          'If it rains, the match is cancelled.\n'
          'The match was not cancelled.',
      options: [
        'It rained',
        'It did not rain',
        'The match was postponed',
        'Nothing can be concluded',
      ],
      correctIndex: 1,
      explanation:
          'Denying the consequent denies the antecedent: if rain guarantees '
          'cancellation and there was no cancellation, there was no rain.',
    ),
    TextQuestion(
      id: 'l4',
      category: QuestionCategory.logical,
      difficulty: 3,
      prompt:
          'In a race you overtake the runner in second place. '
          'What position are you in now?',
      options: ['First', 'Second', 'Third', 'Cannot be determined'],
      correctIndex: 1,
      explanation:
          'You take the place of the runner you passed, so you are now second '
          '— not first, since the leader is still ahead of you.',
    ),
    TextQuestion(
      id: 'l5',
      category: QuestionCategory.logical,
      difficulty: 3,
      prompt:
          'Five friends each shake hands with every other friend exactly '
          'once. How many handshakes take place?',
      options: ['5', '10', '20', '25'],
      correctIndex: 1,
      explanation:
          'Each of the 5 people shakes 4 hands, which counts every handshake '
          'twice: (5 x 4) / 2 = 10.',
    ),
    TextQuestion(
      id: 'l6',
      category: QuestionCategory.logical,
      difficulty: 4,
      prompt:
          'Five machines take five minutes to make five widgets. How long '
          'would 100 machines take to make 100 widgets?',
      options: ['5 minutes', '20 minutes', '100 minutes', '500 minutes'],
      correctIndex: 0,
      explanation:
          'One machine makes one widget in five minutes. Adding machines adds '
          'output in parallel, so 100 machines still take five minutes.',
    ),
    TextQuestion(
      id: 'l7',
      category: QuestionCategory.logical,
      difficulty: 4,
      prompt: 'Which conclusion follows with certainty?',
      stimulus: 'All roses are flowers.\nSome flowers fade quickly.',
      options: [
        'All roses fade quickly',
        'Some roses fade quickly',
        'No roses fade quickly',
        'None of these follows with certainty',
      ],
      correctIndex: 3,
      explanation:
          'The flowers that fade quickly need not be the roses. The premises '
          'leave every option open, so none of the three is guaranteed.',
    ),
    TextQuestion(
      id: 'l8',
      category: QuestionCategory.logical,
      difficulty: 5,
      prompt:
          'Each card has a letter on one side and a number on the other. '
          'Which cards must you turn over to test the rule?',
      stimulus:
          'Rule: if a card has a vowel on one side,\n'
          'it has an even number on the other.\n\n'
          'Cards on the table:  A   K   4   7',
      options: ['A only', 'A and 4', 'A and 7', 'A, 4 and 7'],
      correctIndex: 2,
      explanation:
          'Turn A to check it hides an even number, and turn 7 to check it '
          'does not hide a vowel. The 4 is irrelevant — the rule says nothing '
          'about what an even number must hide, so it cannot break the rule.',
    ),
  ];

  // ------------------------------------------------------------------ spatial

  static final List<Question> _spatial = [
    MatrixQuestion(
      id: 's1',
      category: QuestionCategory.spatial,
      difficulty: 1,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle), _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 3), //
        _f(ShapeKind.square), _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 3), //
        _f(ShapeKind.triangle), _f(ShapeKind.triangle, count: 2), null,
      ],
      options: [
        _f(ShapeKind.triangle, count: 2),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.triangle, count: 3),
        _f(ShapeKind.triangle, count: 3, filled: true),
      ],
      correctIndex: 2,
      explanation:
          'The shape is fixed by the row (circle, square, triangle) and the '
          'count by the column (one, two, three). The last cell is therefore '
          'three outlined triangles.',
    ),
    MatrixQuestion(
      id: 's2',
      category: QuestionCategory.spatial,
      difficulty: 2,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle), _f(ShapeKind.square), _f(ShapeKind.triangle), //
        _f(ShapeKind.square), _f(ShapeKind.triangle), _f(ShapeKind.circle), //
        _f(ShapeKind.triangle), _f(ShapeKind.circle), null,
      ],
      options: [
        _f(ShapeKind.circle),
        _f(ShapeKind.triangle),
        _f(ShapeKind.square),
        _f(ShapeKind.diamond),
      ],
      correctIndex: 2,
      explanation:
          'Every row and every column contains each shape exactly once. The '
          'final row already has a triangle and a circle, so the missing cell '
          'is a square.',
    ),
    MatrixQuestion(
      id: 's3',
      category: QuestionCategory.spatial,
      difficulty: 3,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.arrow), _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 2), //
        _f(ShapeKind.arrow, rot: 1), _f(ShapeKind.arrow, rot: 2),
        _f(ShapeKind.arrow, rot: 3), //
        _f(ShapeKind.arrow, rot: 2), _f(ShapeKind.arrow, rot: 3), null,
      ],
      options: [
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow),
        _f(ShapeKind.arrow, rot: 3),
        _f(ShapeKind.arrow, rot: 2),
      ],
      correctIndex: 1,
      explanation:
          'The arrow turns a quarter turn clockwise at every step, both across '
          'a row and down a column. After three quarter turns it comes full '
          'circle and points right again.',
    ),
    MatrixQuestion(
      id: 's4',
      category: QuestionCategory.spatial,
      difficulty: 3,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle), _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 3), //
        _f(ShapeKind.circle, count: 3), _f(ShapeKind.circle),
        _f(ShapeKind.circle, count: 2), //
        _f(ShapeKind.circle, count: 2), _f(ShapeKind.circle, count: 3), null,
      ],
      options: [
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 4),
      ],
      correctIndex: 1,
      explanation:
          'Counts of one, two and three appear exactly once in every row and '
          'every column. The last row and last column both still need a one.',
    ),
    MatrixQuestion(
      id: 's5',
      category: QuestionCategory.spatial,
      difficulty: 3,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.square), _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 3), //
        _f(ShapeKind.square, count: 2), _f(ShapeKind.square),
        _f(ShapeKind.square, count: 3), //
        _f(ShapeKind.square), _f(ShapeKind.square, count: 3), null,
      ],
      options: [
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.square, count: 4),
        _f(ShapeKind.square, count: 4, filled: true),
      ],
      correctIndex: 2,
      explanation:
          'In each row the third cell holds as many squares as the first two '
          'combined: 1 + 2 = 3, 2 + 1 = 3, and 1 + 3 = 4.',
    ),
    MatrixQuestion(
      id: 's6',
      category: QuestionCategory.spatial,
      difficulty: 4,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.triangle, filled: true),
        _f(ShapeKind.triangle, rot: 1, filled: true),
        _f(ShapeKind.triangle, rot: 2, filled: true), //
        _f(ShapeKind.triangle, rot: 1), _f(ShapeKind.triangle, rot: 2),
        _f(ShapeKind.triangle, rot: 3), //
        _f(ShapeKind.triangle, rot: 2, filled: true),
        _f(ShapeKind.triangle, rot: 3, filled: true), null,
      ],
      options: [
        _f(ShapeKind.triangle),
        _f(ShapeKind.triangle, rot: 3, filled: true),
        _f(ShapeKind.triangle, filled: true),
        _f(ShapeKind.triangle, rot: 1, filled: true),
      ],
      correctIndex: 2,
      explanation:
          'Two rules run at once: the triangle turns a quarter turn clockwise '
          'at each step across a row, and rows alternate solid, outlined, '
          'solid. Three quarter turns from the row start returns it upright, '
          'and the bottom row is solid.',
    ),
    MatrixQuestion(
      id: 's7',
      category: QuestionCategory.spatial,
      difficulty: 4,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle), _f(ShapeKind.circle, count: 2, filled: true),
        _f(ShapeKind.circle, count: 4), //
        _f(ShapeKind.circle, filled: true), _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 4, filled: true), //
        _f(ShapeKind.circle), _f(ShapeKind.circle, count: 2, filled: true),
        null,
      ],
      options: [
        _f(ShapeKind.circle, count: 4, filled: true),
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.circle, count: 4),
        _f(ShapeKind.circle, count: 2),
      ],
      correctIndex: 2,
      explanation:
          'The count doubles across each row (one, two, four) while the fill '
          'flips at every step. The bottom row runs outlined, solid, so the '
          'missing cell is four outlined circles.',
    ),
    MatrixQuestion(
      id: 's8',
      category: QuestionCategory.spatial,
      difficulty: 5,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle, dot: true), _f(ShapeKind.square, count: 2),
        _f(ShapeKind.triangle, count: 3, dot: true), //
        _f(ShapeKind.circle, count: 3, dot: true),
        _f(ShapeKind.square, dot: true),
        _f(ShapeKind.triangle, count: 2), //
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.square, count: 3, dot: true),
        null,
      ],
      options: [
        _f(ShapeKind.triangle),
        _f(ShapeKind.triangle, dot: true),
        _f(ShapeKind.triangle, count: 3, dot: true),
        _f(ShapeKind.circle, dot: true),
      ],
      correctIndex: 1,
      explanation:
          'Three rules combine. The shape is fixed by the column, so the cell '
          'is a triangle. Counts of one, two and three appear once per row and '
          'per column, and both the last row and last column still need a one. '
          'A centre dot appears exactly when the count is odd, so the triangle '
          'carries a dot.',
    ),
  ];
}
