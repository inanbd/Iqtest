using System.Globalization;
using System.Text;
using IqTest.Domain.Questions;
using Microsoft.AspNetCore.Html;

namespace IqTest.Web.Rendering;

/// <summary>
/// Draws a <see cref="FigureSpec"/> as inline SVG, mirroring the Flutter
/// app's CustomPainter so a matrix item looks the same on both platforms.
///
/// Inline SVG rather than images: the puzzles stay resolution-independent and
/// inherit the page's colours, and nothing has to be served as an asset.
/// </summary>
public static class FigureSvg
{
    private const double ViewBox = 100;

    public static IHtmlContent Render(FigureSpec spec, string cssClass = "figure")
    {
        var svg = new StringBuilder();
        svg.Append(CultureInfo.InvariantCulture,
            $"""<svg class="{cssClass}" viewBox="0 0 {ViewBox} {ViewBox}" role="img" aria-label="{Describe(spec)}" focusable="false">""");

        var (columns, rows, scale) = LayoutFor(spec.Count);
        var size = ViewBox * scale;
        var spacing = ViewBox * 0.06;
        var totalWidth = columns * size + (columns - 1) * spacing;
        var totalHeight = rows * size + (rows - 1) * spacing;
        var originX = (ViewBox - totalWidth) / 2;
        var originY = (ViewBox - totalHeight) / 2;
        var strokeWidth = Math.Max(1.6, size * 0.085);

        for (var i = 0; i < spec.Count; i++)
        {
            var column = i % columns;
            var row = i / columns;
            // Outlined shapes are inset by half the stroke so they stay in their slot.
            var inset = spec.Filled ? 0 : strokeWidth / 2;
            var x = originX + column * (size + spacing) + inset;
            var y = originY + row * (size + spacing) + inset;
            var side = size - inset * 2;
            var centreX = x + side / 2;
            var centreY = y + side / 2;

            var transform = spec.RotationQuarters == 0
                ? string.Empty
                : $""" transform="rotate({spec.RotationQuarters * 90} {F(centreX)} {F(centreY)})" """.TrimEnd();

            var fill = spec.Filled ? "currentColor" : "none";
            var stroke = spec.Filled ? "none" : "currentColor";

            svg.Append(CultureInfo.InvariantCulture,
                $"""<g{transform} fill="{fill}" stroke="{stroke}" stroke-width="{F(strokeWidth)}" stroke-linejoin="round">""");
            svg.Append(ShapeMarkup(spec.Shape, x, y, side));
            svg.Append("</g>");

            if (spec.HasDot)
            {
                // On a solid shape the dot is punched out in the page colour.
                var dotFill = spec.Filled ? "var(--surface)" : "currentColor";
                svg.Append(CultureInfo.InvariantCulture,
                    $"""<circle cx="{F(centreX)}" cy="{F(centreY)}" r="{F(size * 0.12)}" fill="{dotFill}" />""");
            }
        }

        svg.Append("</svg>");
        return new HtmlString(svg.ToString());
    }

    /// <summary>Columns, rows and the fraction of the box each shape occupies.</summary>
    private static (int Columns, int Rows, double Scale) LayoutFor(int count) => count switch
    {
        1 => (1, 1, 0.62),
        2 => (2, 1, 0.40),
        3 => (3, 1, 0.27),
        _ => (2, 2, 0.38),
    };

    private static string ShapeMarkup(ShapeKind kind, double x, double y, double side)
    {
        var right = x + side;
        var bottom = y + side;
        var centreX = x + side / 2;
        var centreY = y + side / 2;

        return kind switch
        {
            ShapeKind.Circle =>
                $"""<circle cx="{F(centreX)}" cy="{F(centreY)}" r="{F(side / 2)}" />""",
            ShapeKind.Square =>
                $"""<rect x="{F(x)}" y="{F(y)}" width="{F(side)}" height="{F(side)}" />""",
            ShapeKind.Triangle =>
                Polygon([(centreX, y), (right, bottom), (x, bottom)]),
            ShapeKind.Diamond =>
                Polygon([(centreX, y), (right, centreY), (centreX, bottom), (x, centreY)]),
            ShapeKind.Hexagon => Polygon(RegularPolygon(centreX, centreY, side / 2, 6)),
            ShapeKind.Star => Polygon(Star(centreX, centreY, side / 2)),
            ShapeKind.Arrow => Polygon(Arrow(x, y, side)),
            _ => string.Empty,
        };
    }

    private static (double X, double Y)[] RegularPolygon(double cx, double cy, double radius, int sides) =>
        Enumerable.Range(0, sides)
            .Select(i =>
            {
                var angle = -Math.PI / 2 + i * 2 * Math.PI / sides;
                return (cx + radius * Math.Cos(angle), cy + radius * Math.Sin(angle));
            })
            .ToArray();

    private static (double X, double Y)[] Star(double cx, double cy, double outer)
    {
        var inner = outer * 0.42;
        return Enumerable.Range(0, 10)
            .Select(i =>
            {
                var radius = i % 2 == 0 ? outer : inner;
                var angle = -Math.PI / 2 + i * Math.PI / 5;
                return (cx + radius * Math.Cos(angle), cy + radius * Math.Sin(angle));
            })
            .ToArray();
    }

    /// <summary>An arrow pointing right, so zero quarter turns reads as east.</summary>
    private static (double X, double Y)[] Arrow(double x, double y, double side)
    {
        var midY = y + side / 2;
        var shaftHalf = side * 0.13;
        var neckX = x + side * 0.55;
        return
        [
            (x, midY - shaftHalf),
            (neckX, midY - shaftHalf),
            (neckX, y + side * 0.06),
            (x + side, midY),
            (neckX, y + side - side * 0.06),
            (neckX, midY + shaftHalf),
            (x, midY + shaftHalf),
        ];
    }

    private static string Polygon((double X, double Y)[] points) =>
        $"""<polygon points="{string.Join(' ', points.Select(p => $"{F(p.X)},{F(p.Y)}"))}" />""";

    private static string F(double value) => value.ToString("0.##", CultureInfo.InvariantCulture);

    /// <summary>A short spoken description, for screen readers.</summary>
    public static string Describe(FigureSpec spec)
    {
        var description = new StringBuilder()
            .Append(spec.Count)
            .Append(spec.Filled ? " solid " : " outlined ")
            .Append(spec.Shape.ToString().ToLowerInvariant())
            .Append(spec.Count == 1 ? string.Empty : "s");

        if (spec.RotationQuarters != 0)
            description.Append(CultureInfo.InvariantCulture, $", rotated {spec.RotationQuarters * 90} degrees");
        if (spec.HasDot)
            description.Append(", with a centre dot");

        return description.ToString();
    }
}
