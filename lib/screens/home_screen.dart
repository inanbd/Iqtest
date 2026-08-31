import 'package:flutter/material.dart';

import '../data/question_bank.dart';
import '../models/attempt.dart';
import '../models/question.dart';
import '../navigation.dart';
import '../services/history_store.dart';
import '../state/test_controller.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'quiz_screen.dart';

/// The two sittings the app offers.
enum TestFormat {
  full(
    title: 'Full assessment',
    questionCount: 32,
    timeLimit: Duration(minutes: 25),
    blurb:
        'Every item in the bank, easiest to hardest. The most reliable '
        'reading.',
  ),
  quick(
    title: 'Quick assessment',
    questionCount: 16,
    timeLimit: Duration(minutes: 12),
    blurb: 'A balanced short form — four items from each domain.',
  );

  const TestFormat({
    required this.title,
    required this.questionCount,
    required this.timeLimit,
    required this.blurb,
  });

  final String title;
  final int questionCount;
  final Duration timeLimit;
  final String blurb;

  List<Question> build() => switch (this) {
    TestFormat.full => QuestionBank.fullTest(),
    TestFormat.quick => QuestionBank.quickTest(),
  };
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final HistoryStore _store = HistoryStore();
  late Future<List<Attempt>> _history;

  @override
  void initState() {
    super.initState();
    _history = _store.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  /// Called when a test, or the history screen, is popped off the top.
  @override
  void didPopNext() => _refreshHistory();

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _refreshHistory() {
    setState(() {
      _history = _store.load();
    });
  }

  void _start(TestFormat format) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          controller: TestController(
            questions: format.build(),
            timeLimit: format.timeLimit,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Hero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverList.list(
                children: [
                  FutureBuilder<List<Attempt>>(
                    future: _history,
                    builder: (context, snapshot) {
                      final attempts = snapshot.data ?? const <Attempt>[];
                      if (attempts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _StatsCard(
                          attempts: attempts,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Text(
                    'Choose a format',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final format in TestFormat.values) ...[
                    _FormatCard(
                      format: format,
                      primary: format == TestFormat.full,
                      onTap: () => _start(format),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  const _WhatIsMeasured(),
                  const SizedBox(height: 16),
                  const _ScoringNote(),
                  const SizedBox(height: 20),
                  Text(
                    'This is a practice exercise for entertainment and '
                    'self-comparison. It is not a clinical instrument and its '
                    'scores are not a diagnosis.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.psychology_outlined,
              color: scheme.onPrimary,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Cognitive Index',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A timed reasoning assessment across four domains, scored on the '
            'familiar 100-point scale.',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.88),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.attempts, required this.onTap});

  final List<Attempt> attempts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = attempts.map((a) => a.iq).reduce((a, b) => a > b ? a : b);
    final average =
        attempts.map((a) => a.iq).reduce((a, b) => a + b) / attempts.length;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Attempts',
                      value: '${attempts.length}',
                    ),
                  ),
                  Expanded(
                    child: _Stat(label: 'Best', value: '$best'),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Average',
                      value: average.toStringAsFixed(0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View history',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.format,
    required this.primary,
    required this.onTap,
  });

  final TestFormat format;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: primary ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: primary ? scheme.onPrimaryContainer : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${format.questionCount} questions  ·  '
                      '${format.timeLimit.inMinutes} minutes',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: primary
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      format.blurb,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: primary
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.9)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.play_circle_fill_rounded,
                size: 40,
                color: primary ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatIsMeasured extends StatelessWidget {
  const _WhatIsMeasured();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is measured',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final category in QuestionCategory.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(category.icon, size: 18, color: category.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: '${category.label} — ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: category.description,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoringNote extends StatelessWidget {
  const _ScoringNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Icon(
          Icons.functions_rounded,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'How scoring works',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          Text(
            'Each item carries a weight equal to its difficulty, so a hard '
            'item is worth more than an easy one. Your weighted points are '
            'divided by the points available, and that proportion is placed on '
            'the conventional deviation scale — mean 100, standard deviation '
            '15 — then clamped to 55–145, the range a test this short can '
            'meaningfully separate.\n\n'
            'The reference constants are assumed rather than measured, because '
            'this app has no norming sample. Treat the number as a consistent '
            'yardstick for comparing your own attempts, not as a measurement '
            'of ability.',
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.55,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
