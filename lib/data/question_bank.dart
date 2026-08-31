import 'dart:math';

import '../models/figure_spec.dart';
import '../models/question.dart';
import 'test_blueprint.dart';

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

/// The item pool, and the draw that turns it into one sitting.
///
/// Every domain holds at least two items at difficulty 1 and 2, and at least
/// four at each of 3, 4 and 5 — twice what any blueprint draws from a cell.
/// That surplus is what lets [draw] avoid every item from the previous
/// sitting while still hitting the blueprint exactly.
abstract final class QuestionBank {
  static final List<Question> all = [
    ..._numerical,
    ..._verbal,
    ..._logical,
    ..._spatial,
  ];

  static List<Question> byCategory(QuestionCategory category) =>
      all.where((q) => q.category == category).toList(growable: false);

  /// The items in one (domain, difficulty) cell of the pool.
  static List<Question> cell(QuestionCategory category, int difficulty) => all
      .where((q) => q.category == category && q.difficulty == difficulty)
      .toList(growable: false);

  /// Builds one sitting to [blueprint], ordered easiest to hardest.
  ///
  /// Items whose id is in [avoid] — normally everything the previous sitting
  /// used — are held back and drawn only if a cell would otherwise come up
  /// short. The pool is sized so that never happens for a single sitting's
  /// worth of exclusions, but the fallback keeps the draw correct rather than
  /// short if the pool is ever edited below that.
  static List<Question> draw({
    TestBlueprint blueprint = TestBlueprint.full,
    Set<String> avoid = const {},
    Random? random,
  }) {
    final rng = random ?? Random();
    final picked = <Question>[];

    for (final category in QuestionCategory.values) {
      for (final entry in blueprint.perDifficulty.entries) {
        final candidates = cell(category, entry.key).toList()..shuffle(rng);
        final fresh = [
          for (final q in candidates)
            if (!avoid.contains(q.id)) q,
        ];
        final seen = [
          for (final q in candidates)
            if (avoid.contains(q.id)) q,
        ];
        picked.addAll([...fresh, ...seen].take(entry.value));
      }
    }

    return _orderByDifficulty(picked, rng);
  }

  /// The full sitting: 32 items, 108 weighted points.
  static List<Question> fullTest({
    Set<String> avoid = const {},
    Random? random,
  }) => draw(blueprint: TestBlueprint.full, avoid: avoid, random: random);

  /// The short form: 16 items, 56 weighted points.
  static List<Question> quickTest({
    Set<String> avoid = const {},
    Random? random,
  }) => draw(blueprint: TestBlueprint.quick, avoid: avoid, random: random);

  /// Easiest first, with domains interleaved inside each difficulty band.
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
      difficulty: 2,
      prompt: 'Which number continues the series?',
      stimulus: '1, 3, 6, 10, 15, ?',
      options: ['18', '20', '21', '24'],
      correctIndex: 2,
      explanation:
          'The gaps grow by one each time: 2, 3, 4, 5, then 6. So 15 + 6 = 21. '
          'These are the triangular numbers.',
    ),
    TextQuestion(
      id: 'n5',
      category: QuestionCategory.numerical,
      difficulty: 3,
      prompt: 'Which number continues the series?',
      stimulus: '7, 10, 8, 11, 9, ?',
      options: ['7', '10', '12', '13'],
      correctIndex: 2,
      explanation:
          'The series alternates +3 and -2: 7, 10, 8, 11, 9. The next step is '
          '+3, giving 12.',
    ),
    TextQuestion(
      id: 'n6',
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
      id: 'n7',
      category: QuestionCategory.numerical,
      difficulty: 3,
      prompt: 'Which number continues the series?',
      stimulus: '4, 9, 19, 39, ?',
      options: ['59', '69', '78', '79'],
      correctIndex: 3,
      explanation:
          'Each term is double the previous term plus 1: 39 x 2 + 1 = 79.',
    ),
    TextQuestion(
      id: 'n8',
      category: QuestionCategory.numerical,
      difficulty: 3,
      prompt: 'Which number continues the series?',
      stimulus: '2, 6, 12, 20, 30, ?',
      options: ['36', '40', '42', '44'],
      correctIndex: 2,
      explanation:
          'Each term is n x (n + 1): 1x2, 2x3, 3x4, 4x5, 5x6, then 6x7 = 42. '
          'Equivalently the gaps grow 4, 6, 8, 10, 12.',
    ),
    TextQuestion(
      id: 'n9',
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
      id: 'n10',
      category: QuestionCategory.numerical,
      difficulty: 4,
      prompt: 'Which number continues the series?',
      stimulus: '0, 3, 8, 15, 24, ?',
      options: ['30', '33', '35', '36'],
      correctIndex: 2,
      explanation:
          'Each term is one less than a square: 1-1, 4-1, 9-1, 16-1, 25-1, '
          'then 36-1 = 35.',
    ),
    TextQuestion(
      id: 'n11',
      category: QuestionCategory.numerical,
      difficulty: 4,
      prompt:
          'Two books cost 36 together. The hardback costs 24 more than the '
          'paperback. What does the paperback cost?',
      options: ['6', '9', '12', '14'],
      correctIndex: 0,
      explanation:
          'If the paperback costs x, the hardback costs x + 24 and the pair '
          'costs 2x + 24 = 36, so x = 6. Answering 12 subtracts the difference '
          'from the total instead of splitting what is left.',
    ),
    TextQuestion(
      id: 'n12',
      category: QuestionCategory.numerical,
      difficulty: 4,
      prompt:
          'A shop marks a coat up by 25%, then holds a sale at 20% off the '
          'marked price. Compared with the original price, the sale price is:',
      options: ['5% higher', '5% lower', 'exactly the same', '10% lower'],
      correctIndex: 2,
      explanation:
          'Percentages multiply rather than add: 1.25 x 0.80 = 1.00, so the '
          'sale price is exactly the original. The 20% cut is taken from the '
          'larger marked price, which is why it cancels the 25% rise.',
    ),
    TextQuestion(
      id: 'n13',
      category: QuestionCategory.numerical,
      difficulty: 5,
      prompt: 'Which number continues the series?',
      stimulus: '3, 8, 5, 12, 7, 16, 9, ?',
      options: ['11', '18', '20', '24'],
      correctIndex: 2,
      explanation:
          'Two series are interleaved. The 1st, 3rd, 5th and 7th terms run '
          '3, 5, 7, 9 (+2). The 2nd, 4th and 6th run 8, 12, 16 (+4), so the '
          'next of those is 20.',
    ),
    TextQuestion(
      id: 'n14',
      category: QuestionCategory.numerical,
      difficulty: 5,
      prompt: 'Which number continues the series?',
      stimulus: '1, 2, 2, 4, 8, 32, ?',
      options: ['64', '128', '256', '320'],
      correctIndex: 2,
      explanation:
          'Each term is the product of the two before it: 1x2=2, 2x2=4, '
          '2x4=8, 4x8=32, then 8x32 = 256.',
    ),
    TextQuestion(
      id: 'n15',
      category: QuestionCategory.numerical,
      difficulty: 5,
      prompt: 'Which number continues the series?',
      stimulus: '1, 5, 14, 30, 55, ?',
      options: ['78', '85', '91', '96'],
      correctIndex: 2,
      explanation:
          'Each term adds the next square: +4, +9, +16, +25, then +36. So '
          '55 + 36 = 91. These are the running totals of 1, 4, 9, 16...',
    ),
    TextQuestion(
      id: 'n16',
      category: QuestionCategory.numerical,
      difficulty: 5,
      prompt: 'Which number continues the series?',
      stimulus: '2, 12, 36, 80, 150, ?',
      options: ['210', '238', '252', '264'],
      correctIndex: 2,
      explanation:
          'Each term is n squared times (n + 1): 1x2, 4x3, 9x4, 16x5, 25x6, '
          'then 36x7 = 252.',
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
      difficulty: 3,
      prompt: 'Sculptor is to Marble as Poet is to ?',
      options: ['Rhyme', 'Words', 'Paper', 'Emotion'],
      correctIndex: 1,
      explanation:
          'The relation is maker to the material they shape. Marble is what a '
          'sculptor works in; words are what a poet works in. Paper is what a '
          'poem is recorded on, not what it is made of.',
    ),
    TextQuestion(
      id: 'v9',
      category: QuestionCategory.verbal,
      difficulty: 3,
      prompt: 'Which word does not belong with the others?',
      options: ['Copper', 'Iron', 'Bronze', 'Zinc'],
      correctIndex: 2,
      explanation:
          'Copper, iron and zinc are chemical elements; bronze is an alloy of '
          'copper and tin.',
    ),
    TextQuestion(
      id: 'v10',
      category: QuestionCategory.verbal,
      difficulty: 4,
      prompt: 'Cartographer is to Map as Choreographer is to ?',
      options: ['Music', 'Dance', 'Costume', 'Theatre'],
      correctIndex: 1,
      explanation:
          'The relation is specialist to the thing they design. A '
          'cartographer designs maps; a choreographer designs dances.',
    ),
    TextQuestion(
      id: 'v11',
      category: QuestionCategory.verbal,
      difficulty: 4,
      prompt: 'Drought is to Water as Famine is to ?',
      options: ['Hunger', 'Food', 'Crops', 'Poverty'],
      correctIndex: 1,
      explanation:
          'The relation is a shortage to the thing in short supply. A drought '
          'is a shortage of water; a famine is a shortage of food. Hunger is '
          'the consequence, not the thing lacking.',
    ),
    TextQuestion(
      id: 'v12',
      category: QuestionCategory.verbal,
      difficulty: 4,
      prompt: 'Which word does not belong with the others?',
      options: ['Astronomy', 'Chemistry', 'Alchemy', 'Biology'],
      correctIndex: 2,
      explanation:
          'Astronomy, chemistry and biology are natural sciences; alchemy is '
          'the pre-scientific tradition that chemistry replaced.',
    ),
    TextQuestion(
      id: 'v13',
      category: QuestionCategory.verbal,
      difficulty: 4,
      prompt: 'Ephemeral is to Permanent as Scarce is to ?',
      options: ['Rare', 'Abundant', 'Valuable', 'Limited'],
      correctIndex: 1,
      explanation:
          'The pair are opposites: ephemeral means short-lived, permanent '
          'means lasting. The opposite of scarce is abundant. Rare and limited '
          'are near-synonyms of scarce, not its opposite.',
    ),
    TextQuestion(
      id: 'v14',
      category: QuestionCategory.verbal,
      difficulty: 5,
      prompt: 'Philately is to Stamps as Numismatics is to ?',
      options: ['Books', 'Coins', 'Maps', 'Shells'],
      correctIndex: 1,
      explanation:
          'Each word names the study or collection of a thing. Philately is '
          'the collecting of stamps; numismatics is the study of coins and '
          'currency.',
    ),
    TextQuestion(
      id: 'v15',
      category: QuestionCategory.verbal,
      difficulty: 5,
      prompt: 'Which word does not belong with the others?',
      options: ['Loquacious', 'Taciturn', 'Garrulous', 'Voluble'],
      correctIndex: 1,
      explanation:
          'Loquacious, garrulous and voluble all describe someone who talks a '
          'great deal. Taciturn means the opposite: saying very little.',
    ),
    TextQuestion(
      id: 'v16',
      category: QuestionCategory.verbal,
      difficulty: 5,
      prompt: 'Ostentatious is to Modest as Prodigal is to ?',
      options: ['Generous', 'Frugal', 'Wealthy', 'Careless'],
      correctIndex: 1,
      explanation:
          'The pair are opposites: ostentatious means showy, modest means '
          'unshowy. Prodigal means wastefully extravagant, so its opposite is '
          'frugal. Generous is close in surface meaning but is not the '
          'opposite of prodigal.',
    ),
    TextQuestion(
      id: 'v17',
      category: QuestionCategory.verbal,
      difficulty: 5,
      prompt: 'Which word does not belong with the others?',
      options: ['Ameliorate', 'Assuage', 'Exacerbate', 'Mitigate'],
      correctIndex: 2,
      explanation:
          'Ameliorate, assuage and mitigate all mean to make something less '
          'bad. Exacerbate means to make it worse.',
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
      difficulty: 2,
      prompt: 'Which statement must be true?',
      stimulus: 'No reptiles are mammals.\nAll snakes are reptiles.',
      options: [
        'No snakes are mammals',
        'Some snakes are mammals',
        'All reptiles are snakes',
        'Nothing can be concluded',
      ],
      correctIndex: 0,
      explanation:
          'Snakes are inside the reptiles, and the reptiles are entirely '
          'outside the mammals, so no snake can be a mammal.',
    ),
    TextQuestion(
      id: 'l5',
      category: QuestionCategory.logical,
      difficulty: 3,
      prompt:
          'In a race you overtake the runner in second place. What position '
          'are you in now?',
      options: ['First', 'Second', 'Third', 'Cannot be determined'],
      correctIndex: 1,
      explanation:
          'You take the place of the runner you passed, so you are now second '
          '— not first, since the leader is still ahead of you.',
    ),
    TextQuestion(
      id: 'l6',
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
      id: 'l7',
      category: QuestionCategory.logical,
      difficulty: 3,
      prompt: 'Who finished third?',
      stimulus:
          'Ravi finished ahead of Mia.\nMia finished ahead of Jo.\n'
          'Jo finished ahead of Ken.',
      options: ['Ravi', 'Mia', 'Jo', 'Ken'],
      correctIndex: 2,
      explanation:
          'The three statements chain into a single order: Ravi, Mia, Jo, '
          'Ken. Third in that order is Jo.',
    ),
    TextQuestion(
      id: 'l8',
      category: QuestionCategory.logical,
      difficulty: 3,
      prompt:
          'A drawer holds 5 red socks and 5 blue socks, mixed together in the '
          'dark. What is the smallest number you must take out to be certain '
          'of having a matching pair?',
      options: ['2', '3', '5', '6'],
      correctIndex: 1,
      explanation:
          'Two socks can be one of each colour. A third must repeat one of '
          'those two colours, so three guarantees a pair.',
    ),
    TextQuestion(
      id: 'l9',
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
      id: 'l10',
      category: QuestionCategory.logical,
      difficulty: 4,
      prompt: 'Which conclusion follows with certainty?',
      stimulus: 'Some musicians are teachers.\nAll teachers are patient.',
      options: [
        'All musicians are patient',
        'Some musicians are patient',
        'No musicians are patient',
        'None of these follows with certainty',
      ],
      correctIndex: 1,
      explanation:
          'At least one musician is a teacher, and every teacher is patient, '
          'so at least one musician is patient. Nothing follows about the '
          'musicians who are not teachers.',
    ),
    TextQuestion(
      id: 'l11',
      category: QuestionCategory.logical,
      difficulty: 4,
      prompt:
          'Six identical pumps drain a tank in 90 minutes. Working at the '
          'same rate, how long would nine pumps take?',
      options: [
        '45 minutes',
        '60 minutes',
        '135 minutes',
        'Cannot be determined',
      ],
      correctIndex: 1,
      explanation:
          'The job takes 6 x 90 = 540 pump-minutes however it is shared out, '
          'so nine pumps need 540 / 9 = 60 minutes. More pumps means less '
          'time, so any answer above 90 has the relationship backwards.',
    ),
    TextQuestion(
      id: 'l12',
      category: QuestionCategory.logical,
      difficulty: 4,
      prompt: 'How many people speak both languages?',
      stimulus:
          'In a group of 30 people, 18 speak French and 15 speak German.\n'
          'Everyone speaks at least one of the two.',
      options: ['3', '5', '12', '13'],
      correctIndex: 0,
      explanation:
          'Adding the two counts gives 33, which is 3 more than the 30 people '
          'present. Those 3 have been counted twice, so 3 speak both.',
    ),
    TextQuestion(
      id: 'l13',
      category: QuestionCategory.logical,
      difficulty: 5,
      prompt: 'Whose records must you check to find a violation of the rule?',
      stimulus:
          'Club rule: every member who drives to meetings\n'
          'must hold a parking permit.\n\n'
          'Four member records are face down. What each\n'
          'one shows is:  drives  ·  walks  ·  has a permit\n'
          '·  has no permit',
      options: [
        'Drives, and has a permit',
        'Drives, and has no permit',
        'Drives only',
        'Drives, has a permit, and has no permit',
      ],
      correctIndex: 1,
      explanation:
          'Check the driver, to see whether a permit is missing. Check the '
          'member with no permit, to see whether they drive. The member who '
          'walks cannot break the rule, and neither can the permit holder — '
          'the rule says nothing about what a permit holder must do, so no '
          'record behind those two can violate it.',
    ),
    TextQuestion(
      id: 'l14',
      category: QuestionCategory.logical,
      difficulty: 5,
      prompt: 'What can you conclude?',
      stimulus:
          'On this island every person either always lies\n'
          'or always tells the truth.\n\n'
          'You meet two islanders, A and B.\n'
          'A says: "We are both liars."',
      options: [
        'Both are liars',
        'A lies and B tells the truth',
        'A tells the truth and B lies',
        'Nothing can be concluded',
      ],
      correctIndex: 1,
      explanation:
          'If A told the truth, the claim would be true and A would be a liar '
          '— a contradiction. So A lies, which makes the claim false, so they '
          'are not both liars. Since A is the liar, B must tell the truth.',
    ),
    TextQuestion(
      id: 'l15',
      category: QuestionCategory.logical,
      difficulty: 5,
      prompt:
          'You have 8 identical-looking coins. One is slightly heavier. Using '
          'only a balance scale, what is the fewest weighings that is '
          'guaranteed to find it?',
      options: ['1', '2', '3', '4'],
      correctIndex: 1,
      explanation:
          'Weigh 3 against 3. If they balance, the heavy coin is among the 2 '
          'set aside and a second weighing finds it. If they do not, the heavy '
          'coin is among those 3, and weighing 1 against 1 finds it. Two '
          'weighings always suffice.',
    ),
    TextQuestion(
      id: 'l16',
      category: QuestionCategory.logical,
      difficulty: 5,
      prompt: 'Which box holds the prize?',
      stimulus:
          'One of three boxes — A, B or C — holds a prize.\n'
          'Exactly one of these statements is true:\n\n'
          '1. Box A holds the prize.\n'
          '2. Box B does not hold the prize.\n'
          '3. Box A does not hold the prize.',
      options: ['Box A', 'Box B', 'Box C', 'Cannot be determined'],
      correctIndex: 1,
      explanation:
          'Try each box. If A holds it, statements 1 and 2 are both true — too '
          'many. If C holds it, statements 2 and 3 are both true — too many. '
          'If B holds it, only statement 3 is true, which is exactly one.',
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
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.square),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.triangle),
        _f(ShapeKind.triangle, count: 2),
        null,
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
      difficulty: 1,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.square, filled: true),
        _f(ShapeKind.square),
        _f(ShapeKind.square, filled: true),
        _f(ShapeKind.square),
        _f(ShapeKind.square, filled: true),
        _f(ShapeKind.square),
        _f(ShapeKind.square, filled: true),
        _f(ShapeKind.square),
        null,
      ],
      options: [
        _f(ShapeKind.square),
        _f(ShapeKind.square, filled: true),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.triangle, filled: true),
      ],
      correctIndex: 1,
      explanation:
          'The fill alternates at every step, solid then outlined, running '
          'across the rows and down the columns alike. The cell after an '
          'outlined square is a solid one.',
    ),
    MatrixQuestion(
      id: 's3',
      category: QuestionCategory.spatial,
      difficulty: 2,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle),
        _f(ShapeKind.square),
        _f(ShapeKind.triangle),
        _f(ShapeKind.square),
        _f(ShapeKind.triangle),
        _f(ShapeKind.circle),
        _f(ShapeKind.triangle),
        _f(ShapeKind.circle),
        null,
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
      id: 's4',
      category: QuestionCategory.spatial,
      difficulty: 2,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle),
        _f(ShapeKind.square),
        _f(ShapeKind.triangle),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.triangle, count: 2),
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.square, count: 3),
        null,
      ],
      options: [
        _f(ShapeKind.triangle, count: 2),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.triangle, count: 3),
        _f(ShapeKind.circle, count: 3),
      ],
      correctIndex: 2,
      explanation:
          'The shape is fixed by the column (circle, square, triangle) and the '
          'count by the row (one, two, three) — the opposite arrangement to '
          'the first matrix in the bank. The last cell is three triangles.',
    ),
    MatrixQuestion(
      id: 's5',
      category: QuestionCategory.spatial,
      difficulty: 3,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.arrow),
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 2),
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 2),
        _f(ShapeKind.arrow, rot: 3),
        _f(ShapeKind.arrow, rot: 2),
        _f(ShapeKind.arrow, rot: 3),
        null,
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
      id: 's6',
      category: QuestionCategory.spatial,
      difficulty: 3,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 3),
        null,
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
      id: 's7',
      category: QuestionCategory.spatial,
      difficulty: 3,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.square),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.square),
        _f(ShapeKind.square, count: 3),
        null,
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
      id: 's8',
      category: QuestionCategory.spatial,
      difficulty: 3,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.hexagon),
        _f(ShapeKind.star),
        _f(ShapeKind.diamond),
        _f(ShapeKind.hexagon, filled: true),
        _f(ShapeKind.star, filled: true),
        _f(ShapeKind.diamond, filled: true),
        _f(ShapeKind.hexagon),
        _f(ShapeKind.star),
        null,
      ],
      options: [
        _f(ShapeKind.diamond, filled: true),
        _f(ShapeKind.star),
        _f(ShapeKind.diamond),
        _f(ShapeKind.hexagon),
      ],
      correctIndex: 2,
      explanation:
          'The shape is fixed by the column (hexagon, star, diamond) and the '
          'fill by the row (outlined, solid, outlined). The last cell is an '
          'outlined diamond.',
    ),
    MatrixQuestion(
      id: 's9',
      category: QuestionCategory.spatial,
      difficulty: 4,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.triangle, filled: true),
        _f(ShapeKind.triangle, rot: 1, filled: true),
        _f(ShapeKind.triangle, rot: 2, filled: true),
        _f(ShapeKind.triangle, rot: 1),
        _f(ShapeKind.triangle, rot: 2),
        _f(ShapeKind.triangle, rot: 3),
        _f(ShapeKind.triangle, rot: 2, filled: true),
        _f(ShapeKind.triangle, rot: 3, filled: true),
        null,
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
      id: 's10',
      category: QuestionCategory.spatial,
      difficulty: 4,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, count: 2, filled: true),
        _f(ShapeKind.circle, count: 4),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.circle, count: 4, filled: true),
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, count: 2, filled: true),
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
      id: 's11',
      category: QuestionCategory.spatial,
      difficulty: 4,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.triangle, count: 3),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.triangle),
        _f(ShapeKind.circle, count: 2),
        _f(ShapeKind.triangle, count: 2),
        _f(ShapeKind.circle, count: 3),
        null,
      ],
      options: [
        _f(ShapeKind.circle),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.square),
        _f(ShapeKind.triangle, count: 2),
      ],
      correctIndex: 2,
      explanation:
          'Two rules run independently, and both are the same kind: each of '
          'the three shapes appears exactly once per row and column, and so '
          'does each of the counts one, two and three. The last row still '
          'needs a square, and still needs a count of one.',
    ),
    MatrixQuestion(
      id: 's12',
      category: QuestionCategory.spatial,
      difficulty: 4,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.square, count: 4),
        _f(ShapeKind.square),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.square),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 4),
        _f(ShapeKind.square, count: 2),
        null,
      ],
      options: [
        _f(ShapeKind.square),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.square, count: 4),
      ],
      correctIndex: 1,
      explanation:
          'In each row the third cell holds as many squares as the first minus '
          'the second: 4 - 1 = 3, 3 - 1 = 2, and 4 - 2 = 2.',
    ),
    MatrixQuestion(
      id: 's13',
      category: QuestionCategory.spatial,
      difficulty: 5,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle, dot: true),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.triangle, count: 3, dot: true),
        _f(ShapeKind.circle, count: 3, dot: true),
        _f(ShapeKind.square, dot: true),
        _f(ShapeKind.triangle, count: 2),
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
    MatrixQuestion(
      id: 's14',
      category: QuestionCategory.spatial,
      difficulty: 5,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.circle),
        null,
      ],
      options: [
        _f(ShapeKind.circle),
        _f(ShapeKind.circle, filled: true),
        _f(ShapeKind.square, filled: true),
        _f(ShapeKind.circle, dot: true),
      ],
      correctIndex: 1,
      explanation:
          'The third cell in a row is solid when exactly one of the first two '
          'is solid, and outlined when they match. Row one: outlined and solid '
          'differ, so solid. Row two: both solid, so outlined. Row three: '
          'solid and outlined differ, so the answer is solid.',
    ),
    MatrixQuestion(
      id: 's15',
      category: QuestionCategory.spatial,
      difficulty: 5,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.arrow),
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 2),
        _f(ShapeKind.arrow, rot: 3),
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 3),
        null,
      ],
      options: [
        _f(ShapeKind.arrow, rot: 1),
        _f(ShapeKind.arrow, rot: 2),
        _f(ShapeKind.arrow),
        _f(ShapeKind.arrow, rot: 3),
      ],
      correctIndex: 2,
      explanation:
          'The third arrow in a row is the first two turned together: add the '
          'quarter turns and wrap at a full circle. Row one: 0 + 1 = 1. Row '
          'two: 2 + 3 = 5, which wraps to 1. Row three: 1 + 3 = 4, a full '
          'circle, so the arrow points right again.',
    ),
    MatrixQuestion(
      id: 's16',
      category: QuestionCategory.spatial,
      difficulty: 5,
      prompt: 'Which figure completes the matrix?',
      grid: [
        _f(ShapeKind.circle),
        _f(ShapeKind.square),
        _f(ShapeKind.triangle, count: 2),
        _f(ShapeKind.square),
        _f(ShapeKind.triangle, count: 2),
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.triangle),
        _f(ShapeKind.circle, count: 2),
        null,
      ],
      options: [
        _f(ShapeKind.circle, count: 3),
        _f(ShapeKind.square, count: 2),
        _f(ShapeKind.square, count: 3),
        _f(ShapeKind.triangle, count: 3),
      ],
      correctIndex: 2,
      explanation:
          'Two rules combine. The third shape in a row is whichever of circle, '
          'square and triangle the first two do not use — here a square. The '
          'count is the first two added together — here 1 + 2 = 3.',
    ),
  ];
}
