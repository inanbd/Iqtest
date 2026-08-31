import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/data/question_bank.dart';

import '../tool/questions_export.dart';

/// The exported document is what the ASP.NET site builds its item bank from,
/// so it has to stay in step with the Dart bank it was generated from.
void main() {
  final file = File(questionsExportPath);

  test('the exported file exists', () {
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run: dart run tool/export_questions.dart',
    );
  });

  test('the exported file matches the bank', () {
    expect(
      file.readAsStringSync(),
      renderQuestionsExport(),
      reason:
          'shared/questions.json has drifted from lib/data/question_bank.dart. '
          'Re-run: dart run tool/export_questions.dart',
    );
  });

  group('the exported document', () {
    late Map<String, dynamic> document;

    setUp(() {
      document = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('carries every item', () {
      final questions = document['questions'] as List;
      expect(questions, hasLength(QuestionBank.all.length));
      expect(
        questions.map((q) => (q as Map)['id']).toSet(),
        QuestionBank.all.map((q) => q.id).toSet(),
      );
    });

    test('carries what the site needs to score independently', () {
      for (final raw in document['questions'] as List) {
        final question = raw as Map<String, dynamic>;
        final id = question['id'];
        expect(question['correctIndex'], isA<int>(), reason: '$id');
        expect(question['difficulty'], isA<int>(), reason: '$id');
        expect(question['category'], isA<String>(), reason: '$id');
        expect(question['options'], hasLength(4), reason: '$id');
        expect(question['type'], anyOf('text', 'matrix'), reason: '$id');
      }
    });

    test('carries the blueprints and the scoring constants', () {
      expect(document['blueprints'], {
        'full': {'1': 1, '2': 1, '3': 2, '4': 2, '5': 2},
        'quick': {'2': 1, '3': 1, '4': 1, '5': 1},
      });
      final scoring = document['scoring'] as Map<String, dynamic>;
      expect(scoring['referenceMeanProportion'], 0.55);
      expect(scoring['referenceSdProportion'], 0.19);
      expect(scoring['minIndex'], 55);
      expect(scoring['maxIndex'], 145);
    });

    test('describes matrix figures fully enough to redraw them', () {
      final matrices = (document['questions'] as List)
          .cast<Map<String, dynamic>>()
          .where((q) => q['type'] == 'matrix');
      expect(matrices, hasLength(16));
      for (final question in matrices) {
        final grid = question['grid'] as List;
        expect(grid, hasLength(9), reason: '${question['id']}');
        expect(grid.where((cell) => cell == null), hasLength(1));
        for (final cell in [...grid, ...question['options'] as List]) {
          if (cell == null) continue;
          final figure = cell as Map<String, dynamic>;
          expect(
            figure.keys,
            containsAll(<String>[
              'shape',
              'count',
              'filled',
              'rotationQuarters',
              'hasDot',
            ]),
            reason: '${question['id']}',
          );
        }
      }
    });
  });
}
