import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/data/question_bank.dart';
import 'package:iq_test/models/ranking.dart';
import 'package:iq_test/services/ranking_api.dart';
import 'package:iq_test/services/scoring.dart';

/// Exercises the app's client against a running instance of the ASP.NET
/// service, which is the only way to prove the two platforms really agree.
///
///     dart run tool/export_questions.dart
///     dotnet run --project web/src/IqTest.Web
///     flutter test test_live --dart-define=IQ_API_BASE_URL=http://127.0.0.1:5080
///
/// It lives outside `test/` so a plain `flutter test` does not need a server.
void main() {
  final api = RankingApi(baseUrl: RankingApi.defaultBaseUrl);

  tearDownAll(api.dispose);

  test('the service offers the same country list the app expects', () async {
    final countries = await api.countries();
    expect(countries.length, greaterThan(200));
    expect(countries.map((c) => c.code), contains('GB'));
  });

  test(
    'the service scores a perfect sitting exactly as the app does',
    () async {
      final questions = QuestionBank.fullTest();
      final answers = questions.map<int?>((q) => q.correctIndex).toList();

      final onDevice = Scoring.score(questions: questions, answers: answers);
      final fromService = await api.submit(
        isFullTest: true,
        questions: questions,
        answers: answers,
        duration: const Duration(minutes: 18),
        participant: const ParticipantDetails(
          displayName: 'Live Test',
          countryCode: 'GB',
        ),
      );

      // The whole point of sharing one exported bank and one set of scoring
      // constants: the number is the same whoever works it out.
      expect(fromService.score, onDevice.iq);
      expect(fromService.correct, onDevice.correct);
      expect(fromService.total, onDevice.total);
      expect(fromService.band, onDevice.band);
      expect(fromService.isRanked, isTrue);
      expect(fromService.certificateSlug, hasLength(22));
    },
  );

  test('the service scores a blank sitting exactly as the app does', () async {
    final questions = QuestionBank.fullTest();
    final answers = List<int?>.filled(questions.length, null);

    final onDevice = Scoring.score(questions: questions, answers: answers);
    final fromService = await api.submit(
      isFullTest: true,
      questions: questions,
      answers: answers,
      duration: const Duration(minutes: 2),
    );

    expect(fromService.score, onDevice.iq);
    expect(fromService.correct, 0);
    // No participant was given, so nothing reaches the board.
    expect(fromService.isRanked, isFalse);
  });

  test('the service refuses a sitting that is not a real draw', () async {
    final questions = QuestionBank.fullTest();
    // Swap in a duplicate, which no genuine draw could produce.
    final tampered = [...questions]..[31] = questions[0];

    await expectLater(
      api.submit(
        isFullTest: true,
        questions: tampered,
        answers: tampered.map<int?>((q) => q.correctIndex).toList(),
        duration: const Duration(minutes: 18),
        participant: const ParticipantDetails(
          displayName: 'Tamperer',
          countryCode: 'US',
        ),
      ),
      throwsA(isA<RankingApiException>()),
    );
  });

  test('a submitted result appears on the board', () async {
    final questions = QuestionBank.fullTest();
    final result = await api.submit(
      isFullTest: true,
      questions: questions,
      answers: questions.map<int?>((q) => q.correctIndex).toList(),
      duration: const Duration(minutes: 11),
      participant: ParticipantDetails(
        displayName: 'Board Check ${DateTime.now().millisecondsSinceEpoch}',
        countryCode: 'FR',
      ),
    );

    final board = await api.leaderboard();
    expect(board.totalRows, greaterThan(0));
    expect(
      board.rows.map((r) => r.certificateSlug),
      contains(result.certificateSlug),
    );
  });
}
