import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/question.dart';
import '../services/scoring.dart';

/// Drives one sitting of the test: the answer sheet, the cursor and the clock.
///
/// The clock is a hard limit — when it runs out the test submits itself with
/// whatever has been answered, and unanswered items count as incorrect.
class TestController extends ChangeNotifier {
  TestController({required this.questions, required this.timeLimit})
    : assert(questions.isNotEmpty, 'a test needs at least one question'),
      _answers = List<int?>.filled(questions.length, null),
      _remaining = timeLimit {
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  final List<Question> questions;
  final Duration timeLimit;

  final List<int?> _answers;
  Timer? _ticker;
  Duration _remaining;
  int _currentIndex = 0;
  bool _finished = false;
  ScoreResult? _result;

  /// The answer sheet: one entry per question, `null` where unanswered.
  List<int?> get answers => List.unmodifiable(_answers);

  int get currentIndex => _currentIndex;
  Question get currentQuestion => questions[_currentIndex];
  int? get currentAnswer => _answers[_currentIndex];

  Duration get remaining => _remaining;
  Duration get elapsed => timeLimit - _remaining;
  bool get isFinished => _finished;

  /// Available once the test has been submitted.
  ScoreResult? get result => _result;

  int get answeredCount => _answers.where((a) => a != null).length;
  bool get isComplete => answeredCount == questions.length;
  double get progress => answeredCount / questions.length;

  bool get isFirst => _currentIndex == 0;
  bool get isLast => _currentIndex == questions.length - 1;

  /// True in the final two minutes, so the UI can escalate the timer.
  bool get isRunningOut => _remaining <= const Duration(minutes: 2);

  bool isAnswered(int questionIndex) => _answers[questionIndex] != null;

  void select(int optionIndex) {
    if (_finished) return;
    _answers[_currentIndex] = optionIndex;
    notifyListeners();
  }

  void goTo(int index) {
    if (_finished || index < 0 || index >= questions.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  void next() => goTo(_currentIndex + 1);

  void previous() => goTo(_currentIndex - 1);

  /// Submits the test and computes the result. Safe to call more than once.
  ScoreResult finish() {
    if (_finished) return _result!;
    _finished = true;
    _ticker?.cancel();
    _ticker = null;
    _result = Scoring.score(
      questions: questions,
      answers: _answers,
      elapsed: elapsed,
    );
    notifyListeners();
    return _result!;
  }

  void _tick(Timer timer) {
    if (_finished) return;
    final next = _remaining - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      _remaining = Duration.zero;
      finish();
      return;
    }
    _remaining = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
