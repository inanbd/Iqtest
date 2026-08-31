import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/figure_spec.dart';

/// Renders a [FigureSpec] with a [CustomPainter].
///
/// Drawing the matrix items rather than shipping images keeps every puzzle
/// resolution-independent and lets it inherit the current colour scheme.
class FigureView extends StatelessWidget {
  const FigureView({
    super.key,
    required this.spec,
    this.color,
    this.backgroundColor,
  });

  final FigureSpec spec;

  /// Ink colour for the shapes. Defaults to the scheme's `onSurface`.
  final Color? color;

  /// Colour a centre dot is punched out in when the shape is solid.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _FigurePainter(
        spec: spec,
        color: color ?? scheme.onSurface,
        backgroundColor: backgroundColor ?? scheme.surfaceContainerLow,
      ),
      isComplex: false,
      child: const SizedBox.expand(),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.spec,
    required this.color,
    required this.backgroundColor,
  });

  final FigureSpec spec;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final side = size.shortestSide;
    final (cols, rows, scale) = _layoutFor(spec.count);
    final shapeSize = side * scale;
    final spacing = side * 0.06;

    final totalWidth = cols * shapeSize + (cols - 1) * spacing;
    final totalHeight = rows * shapeSize + (rows - 1) * spacing;
    final originX = (size.width - totalWidth) / 2;
    final originY = (size.height - totalHeight) / 2;

    final strokeWidth = math.max(1.6, shapeSize * 0.085);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = spec.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < spec.count; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      // Inset by half the stroke so an outlined shape stays inside its slot.
      final rect = Rect.fromLTWH(
        originX + col * (shapeSize + spacing),
        originY + row * (shapeSize + spacing),
        shapeSize,
        shapeSize,
      ).deflate(spec.filled ? 0 : strokeWidth / 2);

      canvas.save();
      if (spec.rotationQuarters != 0) {
        canvas
          ..translate(rect.center.dx, rect.center.dy)
          ..rotate(spec.rotationQuarters * math.pi / 2)
          ..translate(-rect.center.dx, -rect.center.dy);
      }
      canvas.drawPath(buildShapePath(spec.shape, rect), paint);
      canvas.restore();

      if (spec.hasDot) {
        canvas.drawCircle(
          rect.center,
          shapeSize * 0.12,
          Paint()..color = spec.filled ? backgroundColor : color,
        );
      }
    }
  }

  /// Columns, rows and the fraction of the box each shape occupies.
  static (int, int, double) _layoutFor(int count) => switch (count) {
    1 => (1, 1, 0.62),
    2 => (2, 1, 0.40),
    3 => (3, 1, 0.27),
    _ => (2, 2, 0.38),
  };

  @override
  bool shouldRepaint(_FigurePainter oldDelegate) =>
      oldDelegate.spec != spec ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}

/// Builds the outline of [kind] inscribed in [rect].
Path buildShapePath(ShapeKind kind, Rect rect) {
  switch (kind) {
    case ShapeKind.circle:
      return Path()..addOval(rect);
    case ShapeKind.square:
      return Path()..addRect(rect);
    case ShapeKind.triangle:
      return Path()
        ..moveTo(rect.center.dx, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
    case ShapeKind.diamond:
      return Path()
        ..moveTo(rect.center.dx, rect.top)
        ..lineTo(rect.right, rect.center.dy)
        ..lineTo(rect.center.dx, rect.bottom)
        ..lineTo(rect.left, rect.center.dy)
        ..close();
    case ShapeKind.hexagon:
      return _regularPolygon(rect, 6);
    case ShapeKind.star:
      return _star(rect, points: 5);
    case ShapeKind.arrow:
      return _arrow(rect);
  }
}

Path _regularPolygon(Rect rect, int sides) {
  final centre = rect.center;
  final radius = rect.shortestSide / 2;
  final path = Path();
  for (var i = 0; i < sides; i++) {
    final angle = -math.pi / 2 + i * 2 * math.pi / sides;
    final point = Offset(
      centre.dx + radius * math.cos(angle),
      centre.dy + radius * math.sin(angle),
    );
    i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

Path _star(Rect rect, {required int points}) {
  final centre = rect.center;
  final outer = rect.shortestSide / 2;
  final inner = outer * 0.42;
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outer : inner;
    final angle = -math.pi / 2 + i * math.pi / points;
    final point = Offset(
      centre.dx + radius * math.cos(angle),
      centre.dy + radius * math.sin(angle),
    );
    i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

/// An arrow pointing right, so a rotation of zero quarter turns reads as
/// "east" and each quarter turn advances it clockwise.
Path _arrow(Rect rect) {
  final w = rect.width;
  final h = rect.height;
  final midY = rect.center.dy;
  final shaftHalf = h * 0.13;
  final neckX = rect.left + w * 0.55;
  return Path()
    ..moveTo(rect.left, midY - shaftHalf)
    ..lineTo(neckX, midY - shaftHalf)
    ..lineTo(neckX, rect.top + h * 0.06)
    ..lineTo(rect.right, midY)
    ..lineTo(neckX, rect.bottom - h * 0.06)
    ..lineTo(neckX, midY + shaftHalf)
    ..lineTo(rect.left, midY + shaftHalf)
    ..close();
}
