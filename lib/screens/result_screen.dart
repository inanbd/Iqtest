import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attempt.dart';
import '../models/question.dart';
import '../models/ranking.dart';
import '../services/history_store.dart';
import '../services/ranking_api.dart';
import '../services/scoring.dart';
import '../widgets/bell_curve.dart';
import '../widgets/category_breakdown.dart';
import '../widgets/submit_score_sheet.dart';
import 'about_screen.dart';
import 'leaderboard_screen.dart';
import 'review_screen.dart';

/// Reports the outcome of a sitting and files it in the local history.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.answers,
  });

  final ScoreResult result;
  final List<Question> questions;
  final List<int?> answers;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final RankingApi _api = RankingApi();
  SubmissionResult? _submission;

  @override
  void initState() {
    super.initState();
    _save();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// Sends the answers — never the score — for the service to mark itself.
  Future<void> _submitToBoard() async {
    final result = await showModalBottomSheet<SubmissionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SubmitScoreSheet(
        api: _api,
        isRankable: widget.questions.length == 32,
        onSubmit: (participant) => _api.submit(
          isFullTest: widget.questions.length == 32,
          questions: widget.questions,
          answers: widget.answers,
          duration: widget.result.elapsed,
          participant: participant,
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _submission = result);
  }

  Future<void> _openCertificate() async {
    final slug = _submission?.certificateSlug;
    if (slug == null) return;
    final uri = Uri.parse(_api.certificateUrl(slug));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $uri')));
    }
  }

  Future<void> _save() async {
    final result = widget.result;
    await HistoryStore().add(
      Attempt(
        takenAt: DateTime.now(),
        iq: result.iq,
        correct: result.correct,
        total: result.total,
        duration: result.elapsed,
        categoryAccuracy: {
          for (final entry in result.byCategory.entries)
            entry.key: entry.value.accuracy,
        },
        // Recorded so the next sitting can draw around them.
        itemIds: widget.questions.map((q) => q.id).toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;

    return PopScope(
      // The test is over; back should return to the home screen, not the quiz.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Your result'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Done'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ScoreHeadline(result: result),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where you land',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Higher than about '
                        '${result.percentile.toStringAsFixed(0)}% of the '
                        'reference distribution.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      BellCurve(index: result.iq),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Correct',
                      value: '${result.correct}/${result.total}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.speed_rounded,
                      label: 'Weighted',
                      value: '${(result.weightedProportion * 100).round()}%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.timer_outlined,
                      label: 'Time',
                      value: _formatDuration(result.elapsed),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By domain',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CategoryBreakdown(scores: result.byCategory),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _BoardCard(
                submission: _submission,
                onSubmit: _submitToBoard,
                onOpenCertificate: _openCertificate,
                onOpenBoard: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LeaderboardScreen(
                      highlightSlug: _submission?.certificateSlug,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(
                      questions: widget.questions,
                      answers: widget.answers,
                    ),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Review every answer'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('How this score was worked out'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to start'),
              ),
              const SizedBox(height: 20),
              Text(
                'Scores from a short, un-normed test move around between '
                'sittings. Practice, fatigue and familiarity all shift the '
                'number, so read it as a rough indicator rather than a '
                'measurement.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
}

class _ScoreHeadline extends StatelessWidget {
  const _ScoreHeadline({required this.result});

  final ScoreResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'COGNITIVE INDEX',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: result.iq.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              value.round().toString(),
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 68,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              result.band,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
        ),
      ),
    );
  }
}

/// Offers the board before submission, and the certificate link after.
class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.submission,
    required this.onSubmit,
    required this.onOpenCertificate,
    required this.onOpenBoard,
  });

  final SubmissionResult? submission;
  final VoidCallback onSubmit;
  final VoidCallback onOpenCertificate;
  final VoidCallback onOpenBoard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (submission case final result?) {
      return Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.isRanked && result.rank != null
                          ? 'Submitted — ranked #\${result.rank}'
                          : 'Submitted',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                result.isRanked
                    ? 'The service scored your answers at \${result.score} and '
                          'placed you on the shared board.'
                    : 'The service scored your answers at \${result.score}. This '
                          'sitting is not ranked, but the certificate is yours.',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onOpenCertificate,
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: const Text('Open my certificate'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onOpenBoard,
                child: const Text('See the leaderboard'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join the global board',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Send your answers to be scored by the shared service, and get a '
              'certificate with its own link. The app and the website rank on '
              'one board.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.leaderboard_outlined, size: 18),
              label: const Text('Submit my result'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenBoard,
              child: const Text('Just show me the board'),
            ),
          ],
        ),
      ),
    );
  }
}
