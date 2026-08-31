namespace IqTest.Domain.Questions;

/// <summary>The geometric primitives the matrix items are drawn from.</summary>
public enum ShapeKind
{
    Circle,
    Square,
    Triangle,
    Diamond,
    Hexagon,
    Star,
    Arrow,
}

/// <summary>
/// A declarative description of one cell, or one answer option, of a matrix
/// item. Mirrors the Dart <c>FigureSpec</c> so both platforms draw the same
/// puzzle from the same data.
/// </summary>
/// <param name="Shape">Which primitive to draw.</param>
/// <param name="Count">How many copies the cell holds (1..4).</param>
/// <param name="Filled">Whether the shapes are solid rather than outlined.</param>
/// <param name="RotationQuarters">Clockwise rotation in quarter turns (0..3).</param>
/// <param name="HasDot">Whether each shape carries a centre dot.</param>
public sealed record FigureSpec(
    ShapeKind Shape,
    int Count = 1,
    bool Filled = false,
    int RotationQuarters = 0,
    bool HasDot = false);
