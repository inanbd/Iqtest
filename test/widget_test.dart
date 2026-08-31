import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/main.dart';
import 'package:iq_test/models/figure_spec.dart';
import 'package:iq_test/models/question.dart';
import 'package:iq_test/screens/quiz_screen.dart';
import 'package:iq_test/screens/result_screen.dart';
import 'package:iq_test/state/test_controller.dart';
import 'package:iq_test/widgets/answer_option.dart';
import 'package:iq_test/widgets/figure_view.dart';
import 'package:iq_test/widgets/matrix_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Question> _textQuestions(int count) => [
  for (var i = 0; i < count; i++)
    TextQuestion(
      id: 'q$i',
      category: QuestionCategory.verbal,
      difficulty: 2,
      prompt: 'Question number $i',
      options: const ['first', 'second', 'third', 'fourth'],
      correctIndex: 0,
      explanation: 'the first option is correct',
    ),
];

/// Answers whatever kind of item is on screen by tapping its first option.
///
/// Matrix items put their options below the fold, so the option is scrolled
/// into view first.
Future<void> _answerFirstOption(WidgetTester tester) async {
  final textOptions = find.byType(TextOptionTile);
  final option = textOptions.evaluate().isNotEmpty
      ? textOptions.first
      : find.byType(FigureOptionTile).first;
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home screen offers both formats', (tester) async {
    await tester.pumpWidget(const IqTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Cognitive Index'), findsOneWidget);
    expect(find.text('Full assessment'), findsOneWidget);
    expect(find.text('Quick assessment'), findsOneWidget);
    expect(find.text('32 questions  ·  25 minutes'), findsOneWidget);
    expect(find.text('16 questions  ·  12 minutes'), findsOneWidget);
    // Nothing has been taken yet, so no stats card.
    expect(find.text('View history'), findsNothing);
  });

  testWidgets('starting a quick test opens the first question', (tester) async {
    await tester.pumpWidget(const IqTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 16'), findsOneWidget);
    expect(find.byType(QuizScreen), findsOneWidget);

    // Unmount so the countdown timer is cancelled with the screen.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('answers persist as the candidate moves between questions', (
    tester,
  ) async {
    // Driven from an explicit controller: which item type the quick test
    // draws first is random, and this case is about the answer sheet.
    final controller = TestController(
      questions: _textQuestions(3),
      timeLimit: const Duration(minutes: 5),
    );
    await tester.pumpWidget(
      MaterialApp(home: QuizScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await _answerFirstOption(tester);
    expect(
      tester.widget<TextOptionTile>(find.byType(TextOptionTile).first).state,
      OptionState.selected,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Question 2 of 3'), findsOneWidget);
    expect(
      tester.widget<TextOptionTile>(find.byType(TextOptionTile).first).state,
      OptionState.idle,
      reason: 'a fresh question starts unanswered',
    );

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(
      tester.widget<TextOptionTile>(find.byType(TextOptionTile).first).state,
      OptionState.selected,
      reason: 'the earlier answer should still be selected',
    );
    expect(controller.answers, [0, null, null]);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the question map reports progress and jumps between items', (
    tester,
  ) async {
    await tester.pumpWidget(const IqTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick assessment'));
    await tester.pumpAndSettle();
    await _answerFirstOption(tester);

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1 of 16 answered'), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.text('Question 5 of 16'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('abandoning asks for confirmation and returns home', (
    tester,
  ) async {
    await tester.pumpWidget(const IqTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick assessment'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Abandon the test?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandon'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizScreen), findsNothing);
    expect(find.text('Full assessment'), findsOneWidget);
  });

  testWidgets('a full sitting produces a score, a history entry and a review', (
    tester,
  ) async {
    await tester.pumpWidget(const IqTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick assessment'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 16; i++) {
      await _answerFirstOption(tester);
      if (i < 15) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Submit the test?'), findsOneWidget);
    expect(
      find.text(
        'All questions are answered. You will not be able to change your '
        'answers after this.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Submit'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('COGNITIVE INDEX'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('By domain'), 200);
    await tester.pumpAndSettle();
    for (final category in QuestionCategory.values) {
      expect(find.text(category.label), findsOneWidget);
    }

    // The review screen marks the answers.
    await tester.scrollUntilVisible(find.text('Review every answer'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review every answer'));
    await tester.pumpAndSettle();
    expect(find.text('All 16'), findsOneWidget);
    expect(find.textContaining('Question 1  ·  '), findsOneWidget);

    await tester.tap(find.textContaining('Question 1  ·  '));
    await tester.pumpAndSettle();
    expect(find.text('Why'), findsOneWidget);

    // Back out to the home screen; the attempt should now be recorded.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('View history'), findsOneWidget);
    expect(find.text('Attempts'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);

    await tester.tap(find.text('View history'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('/16 correct'), findsOneWidget);
  });

  testWidgets('an expired clock submits whatever has been answered', (
    tester,
  ) async {
    final controller = TestController(
      questions: [
        const TextQuestion(
          id: 'x',
          category: QuestionCategory.logical,
          difficulty: 3,
          prompt: 'Pick the first option',
          options: ['right', 'wrong', 'also wrong', 'still wrong'],
          correctIndex: 0,
          explanation: 'the first option is correct',
        ),
      ],
      timeLimit: const Duration(seconds: 3),
    );

    await tester.pumpWidget(
      MaterialApp(home: QuizScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    await _answerFirstOption(tester);

    // Let the clock run out without submitting by hand.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
  });

  group('figure rendering', () {
    testWidgets('draws every shape at every count without overflowing', (
      tester,
    ) async {
      for (final shape in ShapeKind.values) {
        for (var count = 1; count <= 4; count++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: FigureView(
                      spec: FigureSpec(
                        shape: shape,
                        count: count,
                        filled: count.isEven,
                        rotationQuarters: count - 1,
                        hasDot: count.isOdd,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('a matrix grid shows nine cells and marks the blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MatrixGrid(
              cells: [
                FigureSpec(shape: ShapeKind.circle),
                FigureSpec(shape: ShapeKind.square),
                FigureSpec(shape: ShapeKind.triangle),
                FigureSpec(shape: ShapeKind.square),
                FigureSpec(shape: ShapeKind.triangle),
                FigureSpec(shape: ShapeKind.circle),
                FigureSpec(shape: ShapeKind.triangle),
                FigureSpec(shape: ShapeKind.circle),
                null,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FigureView), findsNWidgets(8));
      expect(find.text('?'), findsOneWidget);
    });

    test('describes a figure for screen readers', () {
      expect(
        describeFigure(
          const FigureSpec(
            shape: ShapeKind.triangle,
            count: 3,
            filled: true,
            rotationQuarters: 1,
            hasDot: true,
          ),
        ),
        '3 solid triangles, rotated 90 degrees, with a centre dot',
      );
      expect(
        describeFigure(const FigureSpec(shape: ShapeKind.circle)),
        '1 outlined circle',
      );
    });
  });
}
