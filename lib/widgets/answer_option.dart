import 'package:flutter/material.dart';

import '../models/figure_spec.dart';
import 'figure_view.dart';
import 'matrix_grid.dart';

/// How an option tile should be painted.
enum OptionState {
  /// Neither chosen nor being marked.
  idle,

  /// Chosen by the candidate, before the test is scored.
  selected,

  /// Marking: this was the right answer.
  correct,

  /// Marking: this was chosen and is wrong.
  wrong,
}

/// Shared visual treatment for text and figure answer options.
class _OptionSkin {
  const _OptionSkin(this.border, this.fill, this.badge, this.onBadge);

  final Color border;
  final Color fill;
  final Color badge;
  final Color onBadge;

  static _OptionSkin of(BuildContext context, OptionState state) {
    final scheme = Theme.of(context).colorScheme;
    const correct = Color(0xFF12855F);
    return switch (state) {
      OptionState.idle => _OptionSkin(
        scheme.outlineVariant,
        Colors.transparent,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      OptionState.selected => _OptionSkin(
        scheme.primary,
        scheme.primary.withValues(alpha: 0.10),
        scheme.primary,
        scheme.onPrimary,
      ),
      OptionState.correct => const _OptionSkin(
        correct,
        Color(0x1A12855F),
        correct,
        Colors.white,
      ),
      OptionState.wrong => _OptionSkin(
        scheme.error,
        scheme.error.withValues(alpha: 0.10),
        scheme.error,
        scheme.onError,
      ),
    };
  }
}

Widget _badge(BuildContext context, int index, OptionState state) {
  final skin = _OptionSkin.of(context, state);
  final icon = switch (state) {
    OptionState.correct => Icons.check_rounded,
    OptionState.wrong => Icons.close_rounded,
    _ => null,
  };
  return Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: skin.badge, shape: BoxShape.circle),
    child: icon != null
        ? Icon(icon, size: 18, color: skin.onBadge)
        : Text(
            String.fromCharCode(65 + index),
            style: TextStyle(
              color: skin.onBadge,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
  );
}

/// A tappable text answer.
class TextOptionTile extends StatelessWidget {
  const TextOptionTile({
    super.key,
    required this.index,
    required this.label,
    required this.state,
    this.onTap,
  });

  final int index;
  final String label;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = _OptionSkin.of(context, state);
    return Semantics(
      button: onTap != null,
      selected: state == OptionState.selected,
      child: Material(
        color: skin.fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: skin.border,
                width: state == OptionState.idle ? 1 : 2,
              ),
            ),
            child: Row(
              children: [
                _badge(context, index, state),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable figure answer, used by the matrix items.
class FigureOptionTile extends StatelessWidget {
  const FigureOptionTile({
    super.key,
    required this.index,
    required this.spec,
    required this.state,
    this.onTap,
  });

  final int index;
  final FigureSpec spec;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = _OptionSkin.of(context, state);
    return Semantics(
      button: onTap != null,
      selected: state == OptionState.selected,
      label:
          'Option ${String.fromCharCode(65 + index)}: '
          '${describeFigure(spec)}',
      excludeSemantics: true,
      child: Material(
        color: skin.fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: skin.border,
                width: state == OptionState.idle ? 1 : 2,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                  child: FigureView(spec: spec),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: _badge(context, index, state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
