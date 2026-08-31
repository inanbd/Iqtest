import 'package:flutter/material.dart';

import '../models/attempt.dart';
import '../services/history_store.dart';
import '../services/scoring.dart';

/// Past attempts, newest first, with a trend line across them.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryStore _store = HistoryStore();
  late Future<List<Attempt>> _attempts;

  @override
  void initState() {
    super.initState();
    _attempts = _store.load();
  }

  Future<void> _confirmClear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('Every saved attempt will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (!(clear ?? false)) return;
    await _store.clear();
    if (!mounted) return;
    setState(() => _attempts = _store.load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Attempt>>(
          future: _attempts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final attempts = snapshot.data ?? const <Attempt>[];
            if (attempts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No attempts yet. Finish a test and it will appear here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: attempts.length + (attempts.length > 1 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (attempts.length > 1 && index == 0) {
                  return _TrendCard(attempts: attempts);
                }
                final attempt =
                    attempts[attempts.length > 1 ? index - 1 : index];
                return _AttemptCard(attempt: attempt);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.attempts});

  final List<Attempt> attempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Oldest to newest reads left to right.
    final scores = attempts.reversed.map((a) => a.iq).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trend',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Oldest to newest',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 90,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  scores: scores,
                  lineColor: theme.colorScheme.primary,
                  fillColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.scores,
    required this.lineColor,
    required this.fillColor,
  });

  final List<int> scores;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2 || size.isEmpty) return;
    // Pad the range so a flat run does not collapse onto a single line.
    final lowest = scores.reduce((a, b) => a < b ? a : b) - 5;
    final highest = scores.reduce((a, b) => a > b ? a : b) + 5;
    final span = (highest - lowest).toDouble();

    Offset pointAt(int index) => Offset(
      size.width * index / (scores.length - 1),
      size.height * (1 - (scores[index] - lowest) / span),
    );

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < scores.length; i++) {
      final point = pointAt(i);
      line.lineTo(point.dx, point.dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(area, Paint()..color = fillColor)
      ..drawPath(
        line,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );

    for (var i = 0; i < scores.length; i++) {
      canvas.drawCircle(pointAt(i), 3.2, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      !identical(oldDelegate.scores, scores) ||
      oldDelegate.lineColor != lineColor;
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt});

  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${attempt.iq}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Scoring.bandFor(attempt.iq),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${attempt.correct}/${attempt.total} correct  ·  '
                    '${attempt.duration.inMinutes}m '
                    '${attempt.duration.inSeconds % 60}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(attempt.takenAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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

String _formatDate(DateTime when) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  final hour = when.hour.toString().padLeft(2, '0');
  final minute = when.minute.toString().padLeft(2, '0');
  return '${when.day} ${months[when.month - 1]} ${when.year}  ·  $hour:$minute';
}
