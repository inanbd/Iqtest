import 'dart:convert';

import 'package:iq_test/data/question_bank.dart';
import 'package:iq_test/data/test_blueprint.dart';
import 'package:iq_test/models/figure_spec.dart';
import 'package:iq_test/models/question.dart';
import 'package:iq_test/services/scoring.dart';

/// Where the exported bank lives, relative to the Flutter project root.
const String questionsExportPath = 'shared/questions.json';

/// Bump when the shape of the document changes, not when items change.
const int questionsExportSchemaVersion = 1;

Map<String, dynamic> _figureToJson(FigureSpec spec) => {
  'shape': spec.shape.name,
  'count': spec.count,
  'filled': spec.filled,
  'rotationQuarters': spec.rotationQuarters,
  'hasDot': spec.hasDot,
};

Map<String, dynamic> _questionToJson(Question question) {
  final json = <String, dynamic>{
    'id': question.id,
    'category': question.category.name,
    'difficulty': question.difficulty,
    'prompt': question.prompt,
    'correctIndex': question.correctIndex,
    'explanation': question.explanation,
  };

  switch (question) {
    case TextQuestion(:final options, :final stimulus):
      json['type'] = 'text';
      json['stimulus'] = stimulus;
      json['options'] = options;
    case MatrixQuestion(:final grid, :final options):
      json['type'] = 'matrix';
      json['grid'] = [
        for (final cell in grid) cell == null ? null : _figureToJson(cell),
      ];
      json['options'] = [for (final option in options) _figureToJson(option)];
  }
  return json;
}

Map<String, dynamic> _blueprintToJson(TestBlueprint blueprint) => {
  for (final entry in blueprint.perDifficulty.entries)
    entry.key.toString(): entry.value,
};

/// The whole item bank, the draw blueprints and the scoring constants, as the
/// one document both the Flutter app and the ASP.NET site are built from.
Map<String, dynamic> buildQuestionsExport() => {
  'schemaVersion': questionsExportSchemaVersion,
  'generatedFrom': 'lib/data/question_bank.dart',
  'scoring': {
    'referenceMeanProportion': Scoring.referenceMeanProportion,
    'referenceSdProportion': Scoring.referenceSdProportion,
    'scaleMean': Scoring.scaleMean,
    'scaleSd': Scoring.scaleSd,
    'minIndex': Scoring.minIndex,
    'maxIndex': Scoring.maxIndex,
  },
  'blueprints': {
    'full': _blueprintToJson(TestBlueprint.full),
    'quick': _blueprintToJson(TestBlueprint.quick),
  },
  'questions': [
    // Sorted so the file only changes when the bank does.
    for (final question in [
      ...QuestionBank.all,
    ]..sort((a, b) => a.id.compareTo(b.id)))
      _questionToJson(question),
  ],
};

/// The exact bytes that belong in [questionsExportPath].
String renderQuestionsExport() =>
    '${const JsonEncoder.withIndent('  ').convert(buildQuestionsExport())}\n';
