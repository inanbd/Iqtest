import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/scoring.dart';

/// Plots the reference distribution and marks where a score falls on it.
///
/// The shaded region is everyone scoring at or below [index], which is the
/// visual counterpart of the reported percentile.
class BellCurve extends StatelessWidget {
  const BellCurve({super.key, required this.index, this.height = 170});

  final int index;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Distribution curve. A score of $index sits at the '
          '${Scoring.percentileForIndex(index).toStringAsFixed(0)} percentile.',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: _BellCurvePainter(
              index: index,
              progress: t,
              curveColor: scheme.primary,
              fillColor: scheme.primary.withValues(alpha: 0.22),
              gridColor: scheme.outlineVariant,
              labelColor: scheme.onSurfaceVariant,
              markerColor: scheme.primary,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _BellCurvePainter extends CustomPainter {
  _BellCurvePainter({
    required this.index,
    required this.progress,
    required this.curveColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
    required this.markerColor,
    required this.textDirection,
  });

  final int index;
  final double progress;
  final Color curveColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;
  final Color markerColor;
  final TextDirection textDirection;

  /// Horizontal span of the plot, in index points.
  static const double _minX = 55;
  static const double _maxX = 145;
  static const List<int> _ticks = [70, 85, 100, 115, 130];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const labelHeight = 22.0;
    final plotHeight = math.max(1.0, size.height - labelHeight);
    final peak = Scoring.normalPdf(0);

    double xFor(double value) => (value - _minX) / (_maxX - _minX) * size.width;
    double yFor(double value) {
      final z = (value - Scoring.scaleMean) / Scoring.scaleSd;
      return plotHeight - (Scoring.normalPdf(z) / peak) * (plotHeight * 0.92);
    }

    // Baseline and tick marks.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, plotHeight),
      Offset(size.width, plotHeight),
      gridPaint,
    );
    for (final tick in _ticks) {
      final x = xFor(tick.toDouble());
      canvas.drawLine(
        Offset(x, plotHeight),
        Offset(x, plotHeight + 4),
        gridPaint,
      );
      _label('$tick', labelColor, 11)
        ..layout()
        ..paint(canvas, Offset(x - 11, plotHeight + 6));
    }

    // The curve itself, sampled across the plot width.
    final curve = Path()..moveTo(0, yFor(_minX));
    const steps = 160;
    for (var i = 1; i <= steps; i++) {
      final value = _minX + (_maxX - _minX) * i / steps;
      curve.lineTo(xFor(value), yFor(value));
    }

    // Shade the share of the distribution at or below the score.
    final markerX = xFor(index.toDouble().clamp(_minX, _maxX));
    final shadeTo = markerX * progress;
    final fill = Path()..moveTo(0, plotHeight);
    for (var i = 0; i <= steps; i++) {
      final value = _minX + (_maxX - _minX) * i / steps;
      final x = xFor(value);
      if (x > shadeTo) break;
      fill.lineTo(x, yFor(value));
    }
    fill
      ..lineTo(shadeTo, plotHeight)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);

    canvas.drawPath(
      curve,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..isAntiAlias = true,
    );

    // Marker for the score.
    final markerPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final markerTop = yFor(index.toDouble().clamp(_minX, _maxX));
    canvas.drawLine(
      Offset(markerX, plotHeight),
      Offset(markerX, markerTop + (plotHeight - markerTop) * (1 - progress)),
      markerPaint,
    );
    canvas.drawCircle(Offset(markerX, markerTop), 5 * progress, markerPaint);
  }

  TextPainter _label(String text, Color color, double size) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w500,
      ),
    ),
    textDirection: textDirection,
  );

  @override
  bool shouldRepaint(_BellCurvePainter oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.progress != progress ||
      oldDelegate.curveColor != curveColor;
}
