import 'dart:io';

import 'questions_export.dart';

/// Writes the item bank out for the ASP.NET site to consume.
///
/// Run from the Flutter project root:
///
///     dart run tool/export_questions.dart
///
/// `test/question_export_test.dart` fails if the committed file has drifted
/// from the bank, so the two platforms cannot silently disagree.
void main() {
  final file = File(questionsExportPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(renderQuestionsExport());
  stdout.writeln('Wrote ${file.path}');
}
