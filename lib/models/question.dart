import 'package:meta/meta.dart';

import 'figure_spec.dart';

/// The four reasoning domains the test samples from.
enum QuestionCategory { numerical, verbal, logical, spatial }

extension QuestionCategoryLabel on QuestionCategory {
  String get label => switch (this) {
    QuestionCategory.numerical => 'Numerical',
    QuestionCategory.verbal => 'Verbal',
    QuestionCategory.logical => 'Logical',
    QuestionCategory.spatial => 'Spatial',
  };

  String get description => switch (this) {
    QuestionCategory.numerical => 'Number series and quantitative reasoning',
    QuestionCategory.verbal => 'Analogies, relations and classification',
    QuestionCategory.logical => 'Deduction, inference and problem solving',
    QuestionCategory.spatial => 'Abstract pattern and matrix reasoning',
  };
}

/// A single test item.
///
/// [difficulty] runs 1 (easiest) to 5 (hardest) and doubles as the item's
/// weight when scoring, so harder items contribute more to the final index.
@immutable
sealed class Question {
  const Question({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.prompt,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final QuestionCategory category;
  final int difficulty;
  final String prompt;
  final int correctIndex;
  final String explanation;

  /// How many answer options the item offers.
  int get optionCount;
}

/// An item whose options are written as text.
final class TextQuestion extends Question {
  const TextQuestion({
    required super.id,
    required super.category,
    required super.difficulty,
    required super.prompt,
    required super.correctIndex,
    required super.explanation,
    required this.options,
    this.stimulus,
  });

  final List<String> options;

  /// Optional material shown apart from the prompt — a number series, or the
  /// premises of a syllogism — rendered in a monospaced panel.
  final String? stimulus;

  @override
  int get optionCount => options.length;
}

/// A Raven's-style matrix item.
///
/// [grid] holds nine cells in reading order; exactly one is `null` and marks
/// the cell the candidate must supply.
final class MatrixQuestion extends Question {
  const MatrixQuestion({
    required super.id,
    required super.category,
    required super.difficulty,
    required super.prompt,
    required super.correctIndex,
    required super.explanation,
    required this.grid,
    required this.options,
  });

  final List<FigureSpec?> grid;
  final List<FigureSpec> options;

  /// Index of the blank cell in [grid].
  int get missingIndex => grid.indexWhere((cell) => cell == null);

  @override
  int get optionCount => options.length;
}
