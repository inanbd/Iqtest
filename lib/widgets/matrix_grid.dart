import 'package:flutter/material.dart';

import '../models/figure_spec.dart';
import 'figure_view.dart';

/// The 3x3 stimulus of a matrix-reasoning item.
///
/// A `null` cell is the blank the candidate must fill; when [reveal] is set
/// that cell shows the answer instead of a question mark.
class MatrixGrid extends StatelessWidget {
  const MatrixGrid({
    super.key,
    required this.cells,
    this.reveal,
    this.revealColor,
  });

  final List<FigureSpec?> cells;
  final FigureSpec? reveal;
  final Color? revealColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.clamp(0.0, 340.0);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: cells.length,
              itemBuilder: (context, index) {
                final cell = cells[index];
                final isBlank = cell == null;
                final shown = cell ?? reveal;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: isBlank
                        ? scheme.primary.withValues(alpha: 0.08)
                        : scheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBlank
                          ? scheme.primary.withValues(alpha: 0.55)
                          : Colors.transparent,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: shown == null
                        ? Center(
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: side * 0.11,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          )
                        : Semantics(
                            label: isBlank
                                ? 'Answer: ${_describe(shown)}'
                                : _describe(shown),
                            child: FigureView(
                              spec: shown,
                              color: isBlank
                                  ? (revealColor ?? scheme.primary)
                                  : scheme.onSurface,
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// A short spoken description of a figure, for screen readers.
String describeFigure(FigureSpec spec) => _describe(spec);

String _describe(FigureSpec spec) {
  final buffer = StringBuffer()
    ..write(spec.count)
    ..write(' ')
    ..write(spec.filled ? 'solid ' : 'outlined ')
    ..write(spec.shape.name)
    ..write(spec.count == 1 ? '' : 's');
  if (spec.rotationQuarters != 0) {
    buffer.write(', rotated ${spec.rotationQuarters * 90} degrees');
  }
  if (spec.hasDot) buffer.write(', with a centre dot');
  return buffer.toString();
}
