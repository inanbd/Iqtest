import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iq_test/data/question_bank.dart';
import 'package:iq_test/models/ranking.dart';
import 'package:iq_test/services/ranking_api.dart';

void main() {
  group('submit', () {
    test('sends the items and the answers, and never a score', () async {
      Map<String, dynamic>? sent;

      final api = RankingApi(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'certificateSlug': 'abcdefghijklmnopqrstuv',
              'certificateUrl': '/certificate/abcdefghijklmnopqrstuv',
              'score': 118,
              'percentile': 87.5,
              'band': 'High average',
              'correct': 24,
              'total': 32,
              'isRanked': true,
              'rank': 3,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final questions = QuestionBank.fullTest();
      final answers = List<int?>.generate(
        questions.length,
        (i) => i.isEven ? 0 : null,
      );

      final result = await api.submit(
        isFullTest: true,
        questions: questions,
        answers: answers,
        duration: const Duration(minutes: 14),
        participant: const ParticipantDetails(
          displayName: 'Ada',
          countryCode: 'GB',
          email: 'ada@example.com',
        ),
      );

      expect(sent, isNotNull);
      expect(sent!['format'], 'Full');
      expect(sent!['durationSeconds'], 840);
      expect(sent!['displayName'], 'Ada');
      expect(sent!['countryCode'], 'GB');
      expect(sent!['email'], 'ada@example.com');

      // The payload carries answers, not a verdict.
      expect(sent!.containsKey('score'), isFalse);
      expect(sent!.containsKey('percentile'), isFalse);
      expect(sent!.containsKey('correctIndex'), isFalse);

      final submitted = (sent!['answers'] as List).cast<Map<String, dynamic>>();
      expect(submitted, hasLength(32));
      expect(
        submitted.map((a) => a['questionId']),
        questions.map((q) => q.id),
        reason: 'the ids must line up with the order presented',
      );
      expect(submitted.first.keys.toSet(), {'questionId', 'selectedIndex'});

      // The result is the server's, read back verbatim.
      expect(result.score, 118);
      expect(result.rank, 3);
      expect(result.isRanked, isTrue);
      expect(result.certificateSlug, 'abcdefghijklmnopqrstuv');
    });

    test(
      'omits the participant entirely when submitting anonymously',
      () async {
        Map<String, dynamic>? sent;
        final api = RankingApi(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'certificateSlug': 'a' * 22,
                'certificateUrl': '/certificate/${'a' * 22}',
                'score': 100,
                'percentile': 50.0,
                'band': 'Average',
                'correct': 16,
                'total': 32,
                'isRanked': false,
              }),
              200,
            );
          }),
        );

        final questions = QuestionBank.quickTest();
        await api.submit(
          isFullTest: false,
          questions: questions,
          answers: List<int?>.filled(questions.length, 1),
          duration: const Duration(minutes: 5),
        );

        expect(sent!['format'], 'Quick');
        expect(sent!.containsKey('displayName'), isFalse);
        expect(sent!.containsKey('countryCode'), isFalse);
        expect(sent!.containsKey('email'), isFalse);
      },
    );

    test('surfaces the service\'s own reason for a refusal', () async {
      final api = RankingApi(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'A sitting cannot repeat an item.',
              'type': 'invalid_submission',
            }),
            400,
          ),
        ),
      );

      final questions = QuestionBank.fullTest();
      await expectLater(
        api.submit(
          isFullTest: true,
          questions: questions,
          answers: List<int?>.filled(questions.length, 0),
          duration: const Duration(minutes: 3),
        ),
        throwsA(
          isA<RankingApiException>().having(
            (e) => e.message,
            'message',
            'A sitting cannot repeat an item.',
          ),
        ),
      );
    });

    test(
      'explains an unreachable service rather than leaking the exception',
      () async {
        final api = RankingApi(
          baseUrl: 'https://example.test',
          client: MockClient((_) async => throw http.ClientException('boom')),
        );

        await expectLater(
          api.countries(),
          throwsA(
            isA<RankingApiException>().having(
              (e) => e.message,
              'message',
              contains('Could not reach the ranking service'),
            ),
          ),
        );
      },
    );
  });

  group('leaderboard', () {
    test('reads a page and its rows', () async {
      final api = RankingApi(
        baseUrl: 'https://example.test/',
        client: MockClient((request) async {
          expect(request.url.queryParameters['country'], 'GB');
          expect(request.url.queryParameters['page'], '2');
          return http.Response(
            jsonEncode({
              'rows': [
                {
                  'rank': 4,
                  'displayName': 'Ada',
                  'countryCode': 'GB',
                  'country': 'United Kingdom',
                  'flag': '🇬🇧',
                  'score': 128,
                  'percentile': 96.9,
                  'correct': 28,
                  'total': 32,
                  'durationSeconds': 900,
                  'platform': 'Mobile',
                  'certificateSlug': 'b' * 22,
                  'completedAtUtc': '2026-08-31T10:00:00+00:00',
                },
              ],
              'page': 2,
              'pageSize': 25,
              'totalRows': 30,
              'totalPages': 2,
              'country': 'GB',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final page = await api.leaderboard(countryCode: 'GB', page: 2);

      expect(page.totalRows, 30);
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isFalse);

      final row = page.rows.single;
      expect(row.rank, 4);
      expect(row.displayName, 'Ada');
      expect(row.country, 'United Kingdom');
      expect(row.isMobile, isTrue, reason: 'set on a phone');
    });
  });

  group('certificateUrl', () {
    test('builds the public address, trimming a trailing slash', () {
      final api = RankingApi(
        baseUrl: 'https://iq.example/',
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(api.certificateUrl('xyz'), 'https://iq.example/certificate/xyz');
    });
  });
}
