import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/models/question.dart';
import 'package:iq_test/state/test_controller.dart';

List<Question> _questions(int count) => [
  for (var i = 0; i < count; i++)
    TextQuestion(
      id: 'q$i',
      category: QuestionCategory.values[i % QuestionCategory.values.length],
      difficulty: (i % 5) + 1,
      prompt: 'prompt $i',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: 1,
      explanation: 'because',
    ),
];

void main() {
  group('navigation', () {
    test('starts on the first question', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(4),
          timeLimit: const Duration(minutes: 5),
        );
        expect(controller.currentIndex, 0);
        expect(controller.isFirst, isTrue);
        expect(controller.isLast, isFalse);
        expect(controller.currentAnswer, isNull);
        controller.dispose();
        async.flushTimers();
      });
    });

    test('moves forward and back but never off the ends', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(3),
          timeLimit: const Duration(minutes: 5),
        );
        controller.previous();
        expect(
          controller.currentIndex,
          0,
          reason: 'cannot go before the first',
        );

        controller
          ..next()
          ..next();
        expect(controller.currentIndex, 2);
        expect(controller.isLast, isTrue);

        controller.next();
        expect(controller.currentIndex, 2, reason: 'cannot go past the last');

        controller.previous();
        expect(controller.currentIndex, 1);

        controller.dispose();
        async.flushTimers();
      });
    });

    test('goTo ignores out-of-range indices', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(3),
          timeLimit: const Duration(minutes: 5),
        );
        controller.goTo(2);
        expect(controller.currentIndex, 2);
        controller.goTo(9);
        expect(controller.currentIndex, 2);
        controller.goTo(-1);
        expect(controller.currentIndex, 2);
        controller.dispose();
        async.flushTimers();
      });
    });
  });

  group('answering', () {
    test('records answers against the right question', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(3),
          timeLimit: const Duration(minutes: 5),
        );
        controller.select(2);
        controller.next();
        controller.select(0);

        expect(controller.answers, [2, 0, null]);
        expect(controller.answeredCount, 2);
        expect(controller.isAnswered(0), isTrue);
        expect(controller.isAnswered(2), isFalse);
        expect(controller.isComplete, isFalse);
        expect(controller.progress, closeTo(2 / 3, 1e-9));

        controller.next();
        controller.select(3);
        expect(controller.isComplete, isTrue);

        controller.dispose();
        async.flushTimers();
      });
    });

    test('a later selection replaces an earlier one', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(2),
          timeLimit: const Duration(minutes: 5),
        );
        controller
          ..select(0)
          ..select(3);
        expect(controller.answers.first, 3);
        expect(controller.answeredCount, 1);
        controller.dispose();
        async.flushTimers();
      });
    });

    test('notifies listeners when an answer changes', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(2),
          timeLimit: const Duration(minutes: 5),
        );
        var notifications = 0;
        controller.addListener(() => notifications++);
        controller.select(1);
        expect(notifications, 1);
        controller.next();
        expect(notifications, 2);
        controller.dispose();
        async.flushTimers();
      });
    });
  });

  group('the clock', () {
    test('counts down once a second', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(2),
          timeLimit: const Duration(minutes: 5),
        );
        expect(controller.remaining, const Duration(minutes: 5));
        async.elapse(const Duration(seconds: 30));
        expect(controller.remaining, const Duration(minutes: 4, seconds: 30));
        expect(controller.elapsed, const Duration(seconds: 30));
        controller.dispose();
        async.flushTimers();
      });
    });

    test('flags the final two minutes', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(2),
          timeLimit: const Duration(minutes: 5),
        );
        expect(controller.isRunningOut, isFalse);
        async.elapse(const Duration(minutes: 3, seconds: 1));
        expect(controller.isRunningOut, isTrue);
        controller.dispose();
        async.flushTimers();
      });
    });

    test('submits the test when time runs out', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(4),
          timeLimit: const Duration(seconds: 10),
        );
        controller.select(1); // one correct answer before the buzzer

        async.elapse(const Duration(seconds: 11));

        expect(controller.isFinished, isTrue);
        expect(controller.remaining, Duration.zero);
        expect(controller.result, isNotNull);
        expect(controller.result!.correct, 1);
        expect(controller.result!.total, 4);

        controller.dispose();
        async.flushTimers();
      });
    });

    test('stops ticking once submitted', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(2),
          timeLimit: const Duration(minutes: 5),
        );
        controller.finish();
        final remainingAtFinish = controller.remaining;
        async.elapse(const Duration(seconds: 30));
        expect(controller.remaining, remainingAtFinish);
        controller.dispose();
        async.flushTimers();
      });
    });

    test('cancels the timer on dispose', () {
      fakeAsync((async) {
        TestController(
          questions: _questions(2),
          timeLimit: const Duration(minutes: 5),
        ).dispose();
        async.elapse(const Duration(minutes: 10));
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('finishing', () {
    test('scores the answer sheet and refuses further edits', () {
      fakeAsync((async) {
        final questions = _questions(4);
        final controller = TestController(
          questions: questions,
          timeLimit: const Duration(minutes: 5),
        );
        controller
          ..select(1) // correct
          ..next()
          ..select(1) // correct
          ..next()
          ..select(0); // wrong

        final result = controller.finish();
        expect(result.correct, 2);
        expect(result.total, 4);
        expect(controller.isFinished, isTrue);

        // Locked down after submission.
        controller
          ..select(1)
          ..goTo(0);
        expect(controller.answers[2], 0);
        expect(controller.currentIndex, 2);

        controller.dispose();
        async.flushTimers();
      });
    });

    test('is idempotent', () {
      fakeAsync((async) {
        final controller = TestController(
          questions: _questions(2),
          timeLimit: const Duration(minutes: 5),
        );
        controller.select(1);
        final first = controller.finish();
        final second = controller.finish();
        expect(identical(first, second), isTrue);
        controller.dispose();
        async.flushTimers();
      });
    });
  });
}
