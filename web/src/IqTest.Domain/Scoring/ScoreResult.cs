using IqTest.Domain.Questions;

namespace IqTest.Domain.Scoring;

/// <summary>Per-domain breakdown of a completed sitting.</summary>
public sealed record CategoryScore(QuestionCategory Category, int Correct, int Total)
{
    /// <summary>Proportion correct, 0..1.</summary>
    public double Accuracy => Total == 0 ? 0 : (double)Correct / Total;
}

/// <summary>The outcome of a scored sitting.</summary>
public sealed record ScoreResult(
    int Correct,
    int Total,
    int WeightedPoints,
    int MaxWeightedPoints,
    int Index,
    double Percentile,
    IReadOnlyList<CategoryScore> ByCategory)
{
    /// <summary>Proportion of the available weighted points earned, 0..1.</summary>
    public double WeightedProportion =>
        MaxWeightedPoints == 0 ? 0 : (double)WeightedPoints / MaxWeightedPoints;

    public string Band => DeviationScale.BandFor(Index);
}
