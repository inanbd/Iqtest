using System.Text.Json;
using System.Text.Json.Serialization;
using IqTest.Application.Abstractions;
using IqTest.Domain.Questions;

namespace IqTest.Infrastructure.Questions;

public sealed class QuestionBankOptions
{
    public const string SectionName = "QuestionBank";

    /// <summary>Path to the shared export, absolute or relative to the content root.</summary>
    public string Path { get; set; } = "questions.json";
}

/// <summary>
/// Loads the item pool from <c>shared/questions.json</c>, the document the
/// Flutter app's bank is exported to.
///
/// Both platforms therefore ask the same questions and weight them the same
/// way, and a Dart test fails if the export drifts from the Dart source.
/// </summary>
public sealed class JsonQuestionBank : IQuestionBank
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public JsonQuestionBank(string path)
    {
        if (!File.Exists(path))
            throw new FileNotFoundException(
                $"The shared question bank was not found at '{path}'. " +
                "Run 'dart run tool/export_questions.dart' in the Flutter project.",
                path);

        var document = JsonSerializer.Deserialize<BankDocument>(File.ReadAllText(path), SerializerOptions)
            ?? throw new InvalidOperationException($"The question bank at '{path}' could not be read.");

        SchemaVersion = document.SchemaVersion;
        Pool = new QuestionPool(document.Questions.Select(Map));
        AssertConsistentWithExport(document);
    }

    public QuestionPool Pool { get; }

    public int SchemaVersion { get; }

    private static Question Map(QuestionDocument q) => q.Type switch
    {
        "text" => new TextQuestion(
            q.Id,
            ParseCategory(q.Category),
            q.Difficulty,
            q.Prompt,
            q.Options.Select(o => o.GetString() ?? string.Empty).ToList(),
            q.CorrectIndex,
            q.Explanation,
            q.Stimulus),
        "matrix" => new MatrixQuestion(
            q.Id,
            ParseCategory(q.Category),
            q.Difficulty,
            q.Prompt,
            (q.Grid ?? []).Select(ToFigure).ToList(),
            q.Options.Select(o => ToFigure(Deserialize(o))!).ToList(),
            q.CorrectIndex,
            q.Explanation),
        _ => throw new InvalidOperationException($"Item {q.Id} has unknown type '{q.Type}'."),
    };

    private static FigureDocument? Deserialize(JsonElement element) =>
        element.ValueKind == JsonValueKind.Null
            ? null
            : element.Deserialize<FigureDocument>(SerializerOptions);

    private static FigureSpec? ToFigure(FigureDocument? figure) => figure is null
        ? null
        : new FigureSpec(
            Enum.Parse<ShapeKind>(figure.Shape, ignoreCase: true),
            figure.Count,
            figure.Filled,
            figure.RotationQuarters,
            figure.HasDot);

    private static QuestionCategory ParseCategory(string category) =>
        Enum.Parse<QuestionCategory>(category, ignoreCase: true);

    /// <summary>
    /// Fails fast at start-up rather than mid-test: the scoring constants must
    /// match the ones compiled in, and the pool must be able to serve both
    /// blueprints twice over.
    /// </summary>
    private void AssertConsistentWithExport(BankDocument document)
    {
        var scoring = document.Scoring;
        if (Math.Abs(scoring.ReferenceMeanProportion - Domain.Scoring.DeviationScale.ReferenceMeanProportion) > 1e-9 ||
            Math.Abs(scoring.ReferenceSdProportion - Domain.Scoring.DeviationScale.ReferenceSdProportion) > 1e-9 ||
            scoring.MinIndex != Domain.Scoring.DeviationScale.MinIndex ||
            scoring.MaxIndex != Domain.Scoring.DeviationScale.MaxIndex)
        {
            throw new InvalidOperationException(
                "The shared bank's scoring constants disagree with this build. " +
                "The two platforms would report different scores for the same answers.");
        }

        foreach (var blueprint in new[] { TestBlueprint.Full, TestBlueprint.Quick })
        {
            var shortfalls = Pool.ShortfallsFor(blueprint);
            if (shortfalls.Count > 0)
                throw new InvalidOperationException(
                    $"The pool cannot serve the {blueprint.Format} blueprint: {string.Join(" ", shortfalls)}");
        }
    }

    private sealed record BankDocument(
        int SchemaVersion,
        ScoringDocument Scoring,
        IReadOnlyList<QuestionDocument> Questions);

    private sealed record ScoringDocument(
        double ReferenceMeanProportion,
        double ReferenceSdProportion,
        double ScaleMean,
        double ScaleSd,
        int MinIndex,
        int MaxIndex);

    private sealed record QuestionDocument(
        string Id,
        string Category,
        int Difficulty,
        string Type,
        string Prompt,
        string? Stimulus,
        int CorrectIndex,
        string Explanation,
        IReadOnlyList<JsonElement> Options,
        IReadOnlyList<FigureDocument?>? Grid);

    private sealed record FigureDocument(
        string Shape,
        int Count,
        bool Filled,
        int RotationQuarters,
        bool HasDot);
}
