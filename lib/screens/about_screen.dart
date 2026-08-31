import 'package:flutter/material.dart';

import '../data/question_bank.dart';
import '../data/test_blueprint.dart';
import '../models/question.dart';
import '../services/scoring.dart';
import '../theme/app_theme.dart';
import '../widgets/bell_curve.dart';

/// Explains what the test measures, how a sitting is assembled, and how the
/// number at the end is arrived at — including what it cannot tell you.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How this test works')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: const [
            _Intro(),
            SizedBox(height: 24),
            _WhatItMeasures(),
            SizedBox(height: 16),
            _HowItIsAssembled(),
            SizedBox(height: 16),
            _BlueprintCard(),
            SizedBox(height: 16),
            _HowItIsScored(),
            SizedBox(height: 16),
            _WhatThePercentileMeans(),
            SizedBox(height: 16),
            _WhereItemsComeFrom(),
            SizedBox(height: 16),
            _WhatItCannotTellYou(),
          ],
        ),
      ),
    );
  }
}

/// Section shell: a titled card with body content.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Body copy with comfortable line height.
class _P extends StatelessWidget {
  const _P(this.text, {this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline_rounded, color: scheme.onPrimary, size: 26),
          const SizedBox(height: 12),
          Text(
            'Everything behind the number',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Which items you get, why they are weighted the way they are, how '
            'the score is computed, and what it can and cannot tell you.',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.88),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatItMeasures extends StatelessWidget {
  const _WhatItMeasures();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      icon: Icons.category_outlined,
      title: 'What it measures',
      children: [
        const _P(
          'Four reasoning domains, sampled equally. Each contributes the same '
          'number of items and the same number of available points, so no '
          'single kind of thinking dominates the result.',
        ),
        const SizedBox(height: 14),
        for (final category in QuestionCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(category.icon, size: 18, color: category.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      children: [
                        TextSpan(
                          text: '${category.label} — ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }
}

class _HowItIsAssembled extends StatelessWidget {
  const _HowItIsAssembled();

  @override
  Widget build(BuildContext context) {
    final poolSize = QuestionBank.all.length;
    return _Section(
      icon: Icons.shuffle_rounded,
      title: 'How your sitting is chosen',
      children: [
        _P(
          'The app holds a pool of $poolSize items. A sitting is not the whole '
          'pool — it is a fresh sample drawn from it, so two attempts are made '
          'of largely different questions.',
        ),
        const _P(
          'Sampling at random would make scores incomparable: draw an easy set '
          'one day and a hard set the next and the number moves for reasons '
          'that have nothing to do with you. So the draw follows a fixed '
          'blueprint. It takes a set number of items at each difficulty, from '
          'each domain, every single time.',
          top: 12,
        ),
        const _P(
          'The consequence is the point: the item mix changes between sittings, '
          'but the shape of the test does not. The same number of easy, medium '
          'and hard items, the same points available, the same balance across '
          'the four domains.',
          top: 12,
        ),
        const _P(
          'Within a sitting the items are then ordered easiest to hardest, '
          'with the domains interleaved, so the test warms up rather than '
          'opening on its hardest question.',
          top: 12,
        ),
        const SizedBox(height: 14),
        const _Callout(
          icon: Icons.refresh_rounded,
          text:
              'Every difficulty band holds at least twice as many items as a '
              'sitting draws from it. That surplus is spent deliberately: the '
              'draw holds back everything your last attempt used, so two '
              'consecutive sittings share no questions at all. Seeing an item '
              'again would measure memory rather than reasoning.',
        ),
      ],
    );
  }
}

/// The blueprint, as a small table of difficulty against items drawn.
class _BlueprintCard extends StatelessWidget {
  const _BlueprintCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const categories = QuestionCategory.values;
    const full = TestBlueprint.full;
    const quick = TestBlueprint.quick;

    Widget cell(String text, {bool header = false, bool strong = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style:
              (header
                      ? theme.textTheme.labelMedium
                      : theme.textTheme.bodyMedium)
                  ?.copyWith(
                    fontWeight: header || strong
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: header ? theme.colorScheme.onSurfaceVariant : null,
                  ),
        ),
      );
    }

    String drawn(TestBlueprint blueprint, int difficulty) {
      final count = blueprint.perDifficulty[difficulty] ?? 0;
      return count == 0 ? '—' : '$count';
    }

    return _Section(
      icon: Icons.table_chart_outlined,
      title: 'The blueprint',
      children: [
        const _P(
          'Items drawn from each domain, at each difficulty. Multiply by four '
          'domains for the totals.',
        ),
        const SizedBox(height: 14),
        Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
            top: BorderSide(color: theme.colorScheme.outlineVariant),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              children: [
                cell('Difficulty', header: true),
                cell('Full', header: true),
                cell('Quick', header: true),
              ],
            ),
            for (var difficulty = 1; difficulty <= 5; difficulty++)
              TableRow(
                children: [
                  cell(_difficultyLabel(difficulty)),
                  cell(drawn(full, difficulty)),
                  cell(drawn(quick, difficulty)),
                ],
              ),
            TableRow(
              children: [
                cell('Items', strong: true),
                cell('${full.itemCount(categories.length)}', strong: true),
                cell('${quick.itemCount(categories.length)}', strong: true),
              ],
            ),
            TableRow(
              children: [
                cell('Points available', strong: true),
                cell('${full.maxWeight(categories.length)}', strong: true),
                cell('${quick.maxWeight(categories.length)}', strong: true),
              ],
            ),
          ],
        ),
        const _P(
          'The short form skips the easiest band. Items almost everyone gets '
          'right separate nobody, so with only four items per domain to spend, '
          'they are spent higher up the range.',
          top: 14,
        ),
      ],
    );
  }
}

String _difficultyLabel(int difficulty) => switch (difficulty) {
  1 => '1 · easiest',
  5 => '5 · hardest',
  _ => '$difficulty',
};

class _HowItIsScored extends StatelessWidget {
  const _HowItIsScored();

  @override
  Widget build(BuildContext context) {
    const full = TestBlueprint.full;
    final maxWeight = full.maxWeight(QuestionCategory.values.length);
    return _Section(
      icon: Icons.functions_rounded,
      title: 'How the score is computed',
      children: [
        const _P(
          'Items are not worth the same. Each carries a weight equal to its '
          'difficulty, 1 through 5, so a hard item earns five times what an '
          'easy one does. Getting the hardest items right is what moves the '
          'number.',
        ),
        _P(
          'A full sitting therefore has $maxWeight weighted points available — '
          'the same $maxWeight every time, which is what the fixed blueprint '
          'buys you. Your weighted points are divided by that total to give a '
          'proportion between 0 and 1. An unanswered item scores nothing, the '
          'same as a wrong one.',
          top: 12,
        ),
        const SizedBox(height: 14),
        const _Formula(),
        const SizedBox(height: 14),
        _P(
          'That places you on the deviation scale used by conventional IQ '
          'tests: an average score is 100, and 15 points is one standard '
          'deviation. The result is then clamped to '
          '${Scoring.minIndex}–${Scoring.maxIndex}, because a test of this '
          'length cannot honestly separate the extreme tails.',
        ),
        const SizedBox(height: 14),
        const _Callout(
          icon: Icons.priority_high_rounded,
          text:
              'The two constants in that formula — an average of 0.55 of the '
              'available points, and a spread of 0.19 — are assumed, not '
              'measured. Deriving them properly needs a large sample of real '
              'takers, which this app does not have. They set the scale; they '
              'are not a finding about anybody.',
        ),
      ],
    );
  }
}

class _Formula extends StatelessWidget {
  const _Formula();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style:
            theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.85,
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('p = points earned / points available'),
            Text('z = (p - 0.55) / 0.19'),
            Text('score = 100 + 15z'),
          ],
        ),
      ),
    );
  }
}

class _WhatThePercentileMeans extends StatelessWidget {
  const _WhatThePercentileMeans();

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.show_chart_rounded,
      title: 'What the percentile means',
      children: [
        const _P(
          'The curve on your result is the normal distribution the scale '
          'assumes: most people near 100, fewer as you move out in either '
          'direction. The shaded part is everyone scoring at or below you, and '
          'its size is the percentile.',
        ),
        const _P(
          'A score of 115 sits one standard deviation above the middle, which '
          'is the 84th percentile. 130 is two, at the 98th. The percentile is '
          'computed from your score with the standard normal function, so the '
          'two always agree — it is a restatement of the score, not a second '
          'measurement.',
          top: 12,
        ),
        const SizedBox(height: 8),
        const BellCurve(index: 115, height: 150),
        const SizedBox(height: 4),
        Builder(
          builder: (context) => Text(
            'A score of 115 — one standard deviation above the middle.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _WhereItemsComeFrom extends StatelessWidget {
  const _WhereItemsComeFrom();

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.edit_note_rounded,
      title: 'Where the questions come from',
      children: [
        const _P(
          'Every item was written for this app. The number series use standard '
          'mathematics — Fibonacci, squares, factorials — and the logic items '
          'use standard argument forms that appear in any textbook. The '
          'analogies and the matrices are original.',
        ),
        const _P(
          'The matrices are in the style of Raven\'s Progressive Matrices, but '
          'they are not Raven\'s items. Nothing here is copied from Raven\'s, '
          'the Wechsler scales, or any commercial or clinical test. Those are '
          'copyrighted, and the clinical ones depend on their items staying '
          'out of circulation to keep working.',
          top: 12,
        ),
        const _P(
          'Each matrix is described in code as a rule over shape, count, fill, '
          'rotation and centre dot, rather than drawn by hand. That lets the '
          'test suite re-derive every answer from its rule independently, so a '
          'mis-keyed item or a distractor that accidentally also satisfies the '
          'rule fails the build instead of reaching you.',
          top: 12,
        ),
      ],
    );
  }
}

class _WhatItCannotTellYou extends StatelessWidget {
  const _WhatItCannotTellYou();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      icon: Icons.warning_amber_rounded,
      title: 'What it cannot tell you',
      children: [
        const _Point(
          'It is not normed.',
          'A real test is calibrated against thousands of people. This one is '
              'calibrated against an assumption. The scale is internally '
              'consistent, so comparing your own attempts is meaningful; comparing '
              'your number to a clinically measured one is not.',
        ),
        const _Point(
          'The difficulty ratings are editorial.',
          'Each item was rated 1 to 5 by judgement, not by measuring how many '
              'people actually get it right. Since difficulty is also the scoring '
              'weight, those judgements feed straight into the result.',
        ),
        const _Point(
          'Practice moves the number.',
          'Scores tend to rise across sittings as the formats become familiar, '
              'even without any change in ability. Fresh items on every attempt '
              'reduce that effect but do not remove it.',
        ),
        const _Point(
          'It is a narrow sample.',
          'Thirty-two items in twenty-five minutes touch a small part of what '
              'reasoning involves, and nothing of memory, attention, creativity or '
              'knowledge. Being tired, rushed or unwell will show up in the score '
              'as surely as anything about ability.',
        ),
        _Point(
          'It is not a diagnosis.',
          'Nothing here is a clinical instrument, and no decision worth making '
              'should rest on it. Treat it as a puzzle set that keeps score.',
          last: true,
        ),
        const SizedBox(height: 4),
        Text(
          'Results never leave your device. There is no account, no upload and '
          'no analytics; clearing the history deletes them for good.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.title, this.body, {this.last = false});

  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A highlighted aside inside a section.
class _Callout extends StatelessWidget {
  const _Callout({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
