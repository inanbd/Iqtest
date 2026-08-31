using IqTest.Domain.Questions;
using IqTest.Domain.Scoring;

namespace IqTest.Domain.Tests;

/// <summary>
/// These expectations are the same ones the Dart suite asserts. If the two
/// implementations ever diverge, one of the two suites goes red.
/// </summary>
public sealed class ScoringTests
{
    [Theory]
    [InlineData(0.0, 0.5)]
    [InlineData(1.0, 0.8413)]
    [InlineData(-1.0, 0.1587)]
    [InlineData(1.96, 0.9750)]
    [InlineData(-2.58, 0.0049)]
    public void NormalCdf_matches_published_values(double z, double expected)
        => Assert.Equal(expected, DeviationScale.NormalCdf(z), 4);

    [Theory]
    [InlineData(0.3)]
    [InlineData(1.1)]
    [InlineData(2.4)]
    [InlineData(3.0)]
    public void NormalCdf_is_symmetric(double z)
        => Assert.Equal(1.0, DeviationScale.NormalCdf(z) + DeviationScale.NormalCdf(-z), 6);

    [Fact]
    public void NormalCdf_is_monotonic()
    {
        var previous = 0.0;
        for (var z = -3.0; z <= 3.0; z += 0.25)
        {
            var value = DeviationScale.NormalCdf(z);
            Assert.True(value >= previous, $"CDF dipped at z={z}");
            previous = value;
        }
    }

    [Fact]
    public void The_reference_mean_maps_onto_100()
        => Assert.Equal(100, DeviationScale.IndexForProportion(DeviationScale.ReferenceMeanProportion));

    [Fact]
    public void One_reference_sd_above_the_mean_maps_onto_115()
        => Assert.Equal(115, DeviationScale.IndexForProportion(
            DeviationScale.ReferenceMeanProportion + DeviationScale.ReferenceSdProportion));

    [Fact]
    public void IndexForProportion_is_monotonic_and_stays_in_range()
    {
        var previous = 0;
        for (var p = 0.0; p <= 1.0; p += 0.02)
        {
            var index = DeviationScale.IndexForProportion(p);
            Assert.True(index >= previous);
            Assert.InRange(index, DeviationScale.MinIndex, DeviationScale.MaxIndex);
            previous = index;
        }
    }

    [Theory]
    [InlineData(-1.0)]
    [InlineData(2.0)]
    public void IndexForProportion_clamps_nonsense(double proportion)
        => Assert.InRange(DeviationScale.IndexForProportion(proportion), DeviationScale.MinIndex, DeviationScale.MaxIndex);

    [Fact]
    public void Percentile_agrees_with_the_scale()
    {
        Assert.Equal(50, DeviationScale.PercentileForIndex(100), 2);
        Assert.Equal(84.13, DeviationScale.PercentileForIndex(115), 1);
    }

    [Theory]
    [InlineData(135, "Very superior")]
    [InlineData(125, "Superior")]
    [InlineData(112, "High average")]
    [InlineData(100, "Average")]
    [InlineData(85, "Low average")]
    [InlineData(72, "Borderline")]
    [InlineData(60, "Well below average")]
    public void BandFor_labels_the_conventional_ranges(int index, string expected)
        => Assert.Equal(expected, DeviationScale.BandFor(index));

    /// <summary>
    /// A full sitting always offers 108 weighted points, so a perfect one
    /// scores 136 and a blank one 57 — the figures the Dart suite pins too.
    /// </summary>
    [Fact]
    public void A_perfect_and_a_blank_full_sitting_land_on_the_known_values()
    {
        var questions = BuildFullSitting();

        var perfect = ScoreCalculator.Score(
            questions.Select(q => new AnsweredQuestion(q, q.CorrectIndex)).ToList());
        var blank = ScoreCalculator.Score(
            questions.Select(q => new AnsweredQuestion(q, null)).ToList());

        Assert.Equal(108, perfect.MaxWeightedPoints);
        Assert.Equal(108, perfect.WeightedPoints);
        Assert.Equal(136, perfect.Index);
        Assert.Equal(32, perfect.Correct);

        Assert.Equal(0, blank.WeightedPoints);
        Assert.Equal(57, blank.Index);
    }

    [Fact]
    public void A_hard_item_is_worth_more_than_an_easy_one()
    {
        var easy = new TextQuestion("e", QuestionCategory.Numerical, 1, "?", ["a", "b", "c", "d"], 0, "x");
        var hard = new TextQuestion("h", QuestionCategory.Verbal, 5, "?", ["a", "b", "c", "d"], 0, "x");

        var hardOnly = ScoreCalculator.Score([new(easy, 1), new(hard, 0)]);
        var easyOnly = ScoreCalculator.Score([new(easy, 0), new(hard, 1)]);

        Assert.Equal(hardOnly.Correct, easyOnly.Correct);
        Assert.True(hardOnly.Index > easyOnly.Index);
    }

    [Fact]
    public void Domains_the_sitting_did_not_sample_are_left_out()
    {
        var result = ScoreCalculator.Score([
            new(new TextQuestion("a", QuestionCategory.Numerical, 1, "?", ["a", "b", "c", "d"], 0, "x"), 0),
        ]);

        Assert.Single(result.ByCategory);
        Assert.Equal(QuestionCategory.Numerical, result.ByCategory[0].Category);
        Assert.DoesNotContain(result.ByCategory, c => c.Category == QuestionCategory.Verbal);
    }

    [Fact]
    public void An_unanswered_item_scores_the_same_as_a_wrong_one()
    {
        var question = new TextQuestion("a", QuestionCategory.Logical, 3, "?", ["a", "b", "c", "d"], 0, "x");

        var unanswered = ScoreCalculator.Score([new(question, null)]);
        var wrong = ScoreCalculator.Score([new(question, 2)]);

        Assert.Equal(wrong.Index, unanswered.Index);
        Assert.Equal(0, unanswered.WeightedPoints);
    }

    internal static List<Question> BuildFullSitting()
    {
        var questions = new List<Question>();
        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            foreach (var (difficulty, count) in TestBlueprint.Full.PerDifficulty)
            {
                for (var i = 0; i < count; i++)
                {
                    questions.Add(new TextQuestion(
                        $"{category}-{difficulty}-{i}", category, difficulty, "?",
                        ["a", "b", "c", "d"], 0, "x"));
                }
            }
        }
        return questions;
    }
}
