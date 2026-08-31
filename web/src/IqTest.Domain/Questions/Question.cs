namespace IqTest.Domain.Questions;

/// <summary>
/// A single test item. <see cref="Difficulty"/> runs 1 (easiest) to 5 and
/// doubles as the item's weight when scoring, so harder items count for more.
/// </summary>
public abstract class Question
{
    protected Question(
        string id,
        QuestionCategory category,
        int difficulty,
        string prompt,
        int correctIndex,
        string explanation)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new ArgumentException("An item needs an id.", nameof(id));
        if (difficulty is < 1 or > 5)
            throw new ArgumentOutOfRangeException(nameof(difficulty), difficulty, "Difficulty runs 1 to 5.");

        Id = id;
        Category = category;
        Difficulty = difficulty;
        Prompt = prompt;
        CorrectIndex = correctIndex;
        Explanation = explanation;
    }

    public string Id { get; }
    public QuestionCategory Category { get; }
    public int Difficulty { get; }
    public string Prompt { get; }

    /// <summary>The keyed answer. Never leaves the server before scoring.</summary>
    public int CorrectIndex { get; }

    public string Explanation { get; }

    /// <summary>How many answer options the item offers.</summary>
    public abstract int OptionCount { get; }

    /// <summary>The weight this item contributes, which is its difficulty.</summary>
    public int Weight => Difficulty;

    public bool IsAnsweredCorrectlyBy(int? selectedIndex) => selectedIndex == CorrectIndex;
}

/// <summary>An item whose options are written as text.</summary>
public sealed class TextQuestion : Question
{
    public TextQuestion(
        string id,
        QuestionCategory category,
        int difficulty,
        string prompt,
        IReadOnlyList<string> options,
        int correctIndex,
        string explanation,
        string? stimulus = null)
        : base(id, category, difficulty, prompt, correctIndex, explanation)
    {
        Options = options;
        Stimulus = stimulus;
        if (correctIndex < 0 || correctIndex >= options.Count)
            throw new ArgumentOutOfRangeException(nameof(correctIndex), correctIndex, $"Item {id} keys an option it does not have.");
    }

    public IReadOnlyList<string> Options { get; }

    /// <summary>
    /// Material shown apart from the prompt — a number series, or the premises
    /// of a syllogism.
    /// </summary>
    public string? Stimulus { get; }

    public override int OptionCount => Options.Count;
}

/// <summary>
/// A Raven's-style matrix item. <see cref="Grid"/> holds nine cells in reading
/// order; exactly one is <c>null</c> and marks the blank to be supplied.
/// </summary>
public sealed class MatrixQuestion : Question
{
    public MatrixQuestion(
        string id,
        QuestionCategory category,
        int difficulty,
        string prompt,
        IReadOnlyList<FigureSpec?> grid,
        IReadOnlyList<FigureSpec> options,
        int correctIndex,
        string explanation)
        : base(id, category, difficulty, prompt, correctIndex, explanation)
    {
        if (grid.Count != 9)
            throw new ArgumentException($"Item {id} needs a nine-cell grid.", nameof(grid));
        if (grid.Count(cell => cell is null) != 1)
            throw new ArgumentException($"Item {id} needs exactly one blank cell.", nameof(grid));
        if (correctIndex < 0 || correctIndex >= options.Count)
            throw new ArgumentOutOfRangeException(nameof(correctIndex), correctIndex, $"Item {id} keys an option it does not have.");

        Grid = grid;
        Options = options;
    }

    public IReadOnlyList<FigureSpec?> Grid { get; }
    public IReadOnlyList<FigureSpec> Options { get; }

    /// <summary>Index of the blank cell in <see cref="Grid"/>.</summary>
    public int MissingIndex => Grid.Select((cell, index) => (cell, index)).First(x => x.cell is null).index;

    public override int OptionCount => Options.Count;
}
