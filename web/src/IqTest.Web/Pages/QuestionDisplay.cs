using IqTest.Application.Common;

namespace IqTest.Web.Pages;

/// <summary>
/// How one item should be shown: selectable while the test is running, or
/// marked up once it has been submitted.
/// </summary>
public sealed class QuestionDisplay
{
    public required QuestionView Question { get; init; }
    public int? SelectedIndex { get; init; }

    /// <summary>Set once the test is over, to mark the options.</summary>
    public int? CorrectIndex { get; init; }

    public bool IsInteractive => CorrectIndex is null;

    /// <summary>Fills the matrix blank with the answer during review.</summary>
    public int? RevealIndex => CorrectIndex;

    public string StateFor(int index)
    {
        if (CorrectIndex is not { } correct) return string.Empty;
        if (index == correct) return "correct";
        return index == SelectedIndex ? "wrong" : string.Empty;
    }
}
