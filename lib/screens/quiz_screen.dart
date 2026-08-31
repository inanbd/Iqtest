import 'package:flutter/material.dart';

import '../models/question.dart';
import '../state/test_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_option.dart';
import '../widgets/matrix_grid.dart';
import 'result_screen.dart';

/// Presents one item at a time under a hard time limit.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.controller});

  final TestController controller;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  TestController get _controller => widget.controller;
  bool _navigatedToResult = false;

  @override
  void initState() {
    super.initState();
    // The clock can expire while the candidate is mid-question, so the
    // controller — not a button press — is what moves us to the results.
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_controller.isFinished && !_navigatedToResult) {
      _navigatedToResult = true;
      final result = _controller.result!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(
              result: result,
              questions: _controller.questions,
              answers: _controller.answers,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _controller.questions.length - _controller.answeredCount;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit the test?'),
        content: Text(
          unanswered == 0
              ? 'All questions are answered. You will not be able to change '
                    'your answers after this.'
              : '$unanswered ${unanswered == 1 ? 'question is' : 'questions '
                          'are'} still unanswered and will be marked incorrect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (proceed ?? false) _controller.finish();
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon the test?'),
        content: const Text(
          'Your answers will be discarded and nothing will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if ((quit ?? false) && mounted) Navigator.of(context).pop();
  }

  void _showQuestionMap() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // A 32-item map is taller than the default half-height sheet.
      isScrollControlled: true,
      builder: (sheetContext) => _QuestionMap(
        controller: _controller,
        onSelect: (index) {
          _controller.goTo(index);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final question = _controller.currentQuestion;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || _controller.isFinished) return;
            _confirmQuit();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Abandon test',
                onPressed: _confirmQuit,
              ),
              title: Text(
                'Question ${_controller.currentIndex + 1} '
                'of ${_controller.questions.length}',
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                _TimerChip(
                  remaining: _controller.remaining,
                  urgent: _controller.isRunningOut,
                ),
                IconButton(
                  icon: const Icon(Icons.apps_rounded),
                  tooltip: 'Jump to question',
                  onPressed: _showQuestionMap,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end:
                        (_controller.currentIndex + 1) /
                        _controller.questions.length,
                  ),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, value, _) =>
                      LinearProgressIndicator(value: value, minHeight: 4),
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(question.id),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: QuestionBody(
                        question: question,
                        selectedIndex: _controller.currentAnswer,
                        onSelect: _controller.select,
                      ),
                    ),
                  ),
                  _NavigationBar(
                    controller: _controller,
                    onSubmit: _confirmSubmit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Renders the stem and the options of an item.
///
/// Shared with the review screen, which passes [markingCorrectIndex] to switch
/// the options from "selectable" to "marked".
class QuestionBody extends StatelessWidget {
  const QuestionBody({
    super.key,
    required this.question,
    required this.selectedIndex,
    this.onSelect,
    this.markingCorrectIndex,
  });

  final Question question;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  /// When set the options are shown marked rather than selectable.
  final int? markingCorrectIndex;

  bool get _isMarking => markingCorrectIndex != null;

  OptionState _stateFor(int index) {
    if (_isMarking) {
      if (index == markingCorrectIndex) return OptionState.correct;
      if (index == selectedIndex) return OptionState.wrong;
      return OptionState.idle;
    }
    return index == selectedIndex ? OptionState.selected : OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryChip(question: question),
        const SizedBox(height: 16),
        Text(
          question.prompt,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        if (question case TextQuestion(:final stimulus?)) ...[
          const SizedBox(height: 18),
          _StimulusPanel(text: stimulus),
        ],
        if (question case MatrixQuestion(:final grid)) ...[
          const SizedBox(height: 20),
          MatrixGrid(
            cells: grid,
            reveal: _isMarking
                ? (question as MatrixQuestion).options[markingCorrectIndex!]
                : null,
          ),
        ],
        const SizedBox(height: 24),
        switch (question) {
          TextQuestion(:final options) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                TextOptionTile(
                  index: i,
                  label: options[i],
                  state: _stateFor(i),
                  onTap: onSelect == null ? null : () => onSelect!(i),
                ),
                if (i != options.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
          MatrixQuestion(:final options) => GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: options.length,
            itemBuilder: (context, i) => FigureOptionTile(
              index: i,
              spec: options[i],
              state: _stateFor(i),
              onTap: onSelect == null ? null : () => onSelect!(i),
            ),
          ),
        },
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = question.category.accent;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(question.category.icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Text(
                question.category.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Semantics(
          label: 'Difficulty ${question.difficulty} of 5',
          excludeSemantics: true,
          child: Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= question.difficulty
                          ? accent
                          : theme.colorScheme.outlineVariant,
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

class _StimulusPanel extends StatelessWidget {
  const _StimulusPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          height: 1.6,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.remaining, required this.urgent});

  final Duration remaining;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = urgent ? scheme.error : scheme.onSurfaceVariant;
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Semantics(
      label:
          '${remaining.inMinutes} minutes '
          '${remaining.inSeconds % 60} seconds remaining',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 15, color: colour),
            const SizedBox(width: 5),
            Text(
              '$minutes:$seconds',
              style: TextStyle(
                color: colour,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.controller, required this.onSubmit});

  final TestController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (!controller.isFirst)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.previous,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
              ),
            ),
          if (!controller.isFirst) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: controller.isLast
                ? FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Submit'),
                  )
                : FilledButton.icon(
                    onPressed: controller.next,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Next'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A grid of every question, so the candidate can see what is unanswered and
/// jump straight to it.
class _QuestionMap extends StatelessWidget {
  const _QuestionMap({required this.controller, required this.onSelect});

  final TestController controller;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Questions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${controller.answeredCount} of '
            '${controller.questions.length} answered',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Flexible so the grid scrolls instead of overflowing when the
          // sheet cannot grow any further.
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: controller.questions.length,
              itemBuilder: (context, index) {
                final answered = controller.isAnswered(index);
                final isCurrent = index == controller.currentIndex;
                return Material(
                  color: answered
                      ? scheme.primary.withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isCurrent ? scheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(index),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: answered
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
