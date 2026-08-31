import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/scoring.dart';
import '../theme/app_theme.dart';

/// Per-domain accuracy bars for the results screen.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({super.key, required this.scores});

  final Map<QuestionCategory, CategoryScore> scores;

  @override
  Widget build(BuildContext context) {
    final entries = QuestionCategory.values
        .where(scores.containsKey)
        .map((category) => scores[category]!)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final score in entries) ...[
          _CategoryRow(score: score),
          if (score != entries.last) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.score});

  final CategoryScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = score.category.accent;
    return Semantics(
      label:
          '${score.category.label}: ${score.correct} of ${score.total} '
          'correct',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(score.category.icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  score.category.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${score.correct}/${score.total}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score.accuracy),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
