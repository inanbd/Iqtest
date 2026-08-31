using IqTest.Domain.Questions;

namespace IqTest.Domain.Scoring;

/// <summary>One item as answered by a candidate.</summary>
/// <param name="Question">The item that was presented.</param>
/// <param name="SelectedIndex">The option chosen, or null if left unanswered.</param>
public sealed record AnsweredQuestion(Question Question, int? SelectedIndex)
{
    public bool IsCorrect => Question.IsAnsweredCorrectlyBy(SelectedIndex);
}

/// <summary>
/// Scores an answer sheet. This is the only place a score is produced, on
/// either platform's behalf: submissions carry answers, never scores, so the
/// number on the leaderboard is always one the server worked out itself.
/// </summary>
public static class ScoreCalculator
{
    public static ScoreResult Score(IReadOnlyCollection<AnsweredQuestion> answers)
    {
        ArgumentNullException.ThrowIfNull(answers);

        var correct = 0;
        var weighted = 0;
        var maxWeighted = 0;
        var perCategory = new Dictionary<QuestionCategory, (int Correct, int Total)>();

        foreach (var answer in answers)
        {
            var question = answer.Question;
            maxWeighted += question.Weight;

            var tally = perCategory.GetValueOrDefault(question.Category);
            tally.Total++;

            if (answer.IsCorrect)
            {
                correct++;
                weighted += question.Weight;
                tally.Correct++;
            }

            perCategory[question.Category] = tally;
        }

        var proportion = maxWeighted == 0 ? 0 : (double)weighted / maxWeighted;
        var index = DeviationScale.IndexForProportion(proportion);

        // Domains the sitting did not sample are left out entirely rather than
        // reported as zero.
        var byCategory = Enum.GetValues<QuestionCategory>()
            .Where(perCategory.ContainsKey)
            .Select(category => new CategoryScore(category, perCategory[category].Correct, perCategory[category].Total))
            .ToList();

        return new ScoreResult(
            correct,
            answers.Count,
            weighted,
            maxWeighted,
            index,
            DeviationScale.PercentileForIndex(index),
            byCategory);
    }
}
