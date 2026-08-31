import 'package:flutter/material.dart';

import '../models/question.dart';
import 'quiz_screen.dart';

/// Walks back through every item with the correct answer and an explanation.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.questions,
    required this.answers,
  });

  final List<Question> questions;
  final List<int?> answers;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

enum _ReviewFilter { all, wrong }

class _ReviewScreenState extends State<ReviewScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;

  List<int> get _visibleIndices => [
    for (var i = 0; i < widget.questions.length; i++)
      if (_filter == _ReviewFilter.all ||
          widget.answers[i] != widget.questions[i].correctIndex)
        i,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indices = _visibleIndices;
    final wrongCount = widget.questions
        .asMap()
        .entries
        .where((e) => widget.answers[e.key] != e.value.correctIndex)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SegmentedButton<_ReviewFilter>(
                segments: [
                  ButtonSegment(
                    value: _ReviewFilter.all,
                    label: Text('All ${widget.questions.length}'),
                  ),
                  ButtonSegment(
                    value: _ReviewFilter.wrong,
                    label: Text('Missed $wrongCount'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selection) =>
                    setState(() => _filter = selection.first),
              ),
            ),
            Expanded(
              child: indices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nothing missed — a clean sheet.',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      itemCount: indices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, position) {
                        final index = indices[position];
                        return _ReviewCard(
                          number: index + 1,
                          question: widget.questions[index],
                          answer: widget.answers[index],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.number,
    required this.question,
    required this.answer,
  });

  final int number;
  final Question question;
  final int? answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCorrect = answer == question.correctIndex;
    final status = isCorrect
        ? _Status(
            'Correct',
            Icons.check_circle_rounded,
            const Color(0xFF12855F),
          )
        : answer == null
        ? _Status(
            'Not answered',
            Icons.remove_circle_outline_rounded,
            scheme.onSurfaceVariant,
          )
        : _Status('Incorrect', Icons.cancel_rounded, scheme.error);

    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Icon(status.icon, color: status.colour),
        title: Text(
          'Question $number  ·  ${question.category.label}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          status.label,
          style: theme.textTheme.bodySmall?.copyWith(color: status.colour),
        ),
        children: [
          QuestionBody(
            question: question,
            selectedIndex: answer,
            markingCorrectIndex: question.correctIndex,
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Why',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  question.explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Status {
  const _Status(this.label, this.icon, this.colour);

  final String label;
  final IconData icon;
  final Color colour;
}
