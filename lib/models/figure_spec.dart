import 'package:flutter/foundation.dart';

/// The geometric primitives the matrix-reasoning items are drawn from.
enum ShapeKind { circle, square, triangle, diamond, hexagon, star, arrow }

/// A declarative description of one cell (or one answer option) in a
/// matrix-reasoning item.
///
/// Items are described by rules over these attributes — shape identity, how
/// many copies are drawn, whether they are filled, their orientation and
/// whether they carry a centre dot — so a puzzle is authored as data and
/// rendered by [FigureView] rather than shipped as an image asset.
@immutable
class FigureSpec {
  const FigureSpec({
    required this.shape,
    this.count = 1,
    this.filled = false,
    this.rotationQuarters = 0,
    this.hasDot = false,
  }) : assert(count >= 1 && count <= 4, 'count must be 1..4'),
       assert(
         rotationQuarters >= 0 && rotationQuarters <= 3,
         'rotationQuarters must be 0..3',
       );

  /// Which primitive to draw.
  final ShapeKind shape;

  /// How many copies of [shape] the cell contains (1..4).
  final int count;

  /// Whether the shapes are solid rather than outlined.
  final bool filled;

  /// Clockwise rotation in quarter turns (0..3).
  final int rotationQuarters;

  /// Whether each shape carries a small dot at its centre.
  final bool hasDot;

  FigureSpec copyWith({
    ShapeKind? shape,
    int? count,
    bool? filled,
    int? rotationQuarters,
    bool? hasDot,
  }) {
    return FigureSpec(
      shape: shape ?? this.shape,
      count: count ?? this.count,
      filled: filled ?? this.filled,
      rotationQuarters: rotationQuarters ?? this.rotationQuarters,
      hasDot: hasDot ?? this.hasDot,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FigureSpec &&
        other.shape == shape &&
        other.count == count &&
        other.filled == filled &&
        other.rotationQuarters == rotationQuarters &&
        other.hasDot == hasDot;
  }

  @override
  int get hashCode =>
      Object.hash(shape, count, filled, rotationQuarters, hasDot);

  @override
  String toString() =>
      'FigureSpec(${shape.name} x$count, filled: $filled, '
      'rot: $rotationQuarters, dot: $hasDot)';
}
