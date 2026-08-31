using IqTest.Domain.Questions;

namespace IqTest.Application.Common;

/// <summary>
/// One item as shown to a candidate. Note what is missing: the keyed answer
/// and the explanation never reach the browser before scoring.
/// </summary>
public sealed record QuestionView(
    string Id,
    QuestionCategory Category,
    int Difficulty,
    string Prompt,
    string? Stimulus,
    IReadOnlyList<string>? TextOptions,
    IReadOnlyList<FigureSpec?>? Grid,
    IReadOnlyList<FigureSpec>? FigureOptions)
{
    public bool IsMatrix => Grid is not null;

    public int OptionCount => TextOptions?.Count ?? FigureOptions?.Count ?? 0;

    public static QuestionView From(Question question) => question switch
    {
        TextQuestion text => new QuestionView(
            text.Id, text.Category, text.Difficulty, text.Prompt, text.Stimulus,
            text.Options, null, null),
        MatrixQuestion matrix => new QuestionView(
            matrix.Id, matrix.Category, matrix.Difficulty, matrix.Prompt, null,
            null, matrix.Grid, matrix.Options),
        _ => throw new ArgumentOutOfRangeException(nameof(question)),
    };
}

/// <summary>An item with its answer revealed, for the post-submission review.</summary>
public sealed record ReviewedQuestionView(
    QuestionView Question,
    int CorrectIndex,
    string Explanation,
    int? SelectedIndex)
{
    public bool IsCorrect => SelectedIndex == CorrectIndex;

    public static ReviewedQuestionView From(Question question, int? selectedIndex) =>
        new(QuestionView.From(question), question.CorrectIndex, question.Explanation, selectedIndex);
}

/// <summary>The optional details someone gives to appear on the board.</summary>
public sealed record ParticipantDetails(string DisplayName, string CountryCode, string? Email);

/// <summary>Per-domain result, for display.</summary>
public sealed record CategoryScoreView(QuestionCategory Category, int Correct, int Total)
{
    public double Accuracy => Total == 0 ? 0 : (double)Correct / Total;
}
