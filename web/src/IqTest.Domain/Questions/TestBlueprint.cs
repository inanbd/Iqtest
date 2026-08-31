namespace IqTest.Domain.Questions;

/// <summary>Which sitting a candidate took.</summary>
public enum TestFormat
{
    Full = 1,
    Quick = 2,
}

/// <summary>
/// How many items one sitting draws from each difficulty, within every domain.
///
/// Holding this fixed is what makes two sittings comparable: the items vary
/// from one attempt to the next, but the shape of the test — and therefore the
/// weighted points available — does not.
/// </summary>
public sealed class TestBlueprint
{
    private readonly IReadOnlyDictionary<int, int> _perDifficulty;

    private TestBlueprint(TestFormat format, IReadOnlyDictionary<int, int> perDifficulty)
    {
        Format = format;
        _perDifficulty = perDifficulty;
    }

    public TestFormat Format { get; }

    /// <summary>Difficulty to the number of items drawn at it, per domain.</summary>
    public IReadOnlyDictionary<int, int> PerDifficulty => _perDifficulty;

    /// <summary>The full sitting: eight items per domain spanning the whole range.</summary>
    public static readonly TestBlueprint Full = new(
        TestFormat.Full,
        new Dictionary<int, int> { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 2 });

    /// <summary>
    /// The short form: one item per domain at each difficulty above the easiest
    /// band, which carries the least information about ability.
    /// </summary>
    public static readonly TestBlueprint Quick = new(
        TestFormat.Quick,
        new Dictionary<int, int> { [2] = 1, [3] = 1, [4] = 1, [5] = 1 });

    public static TestBlueprint For(TestFormat format) => format switch
    {
        TestFormat.Full => Full,
        TestFormat.Quick => Quick,
        _ => throw new ArgumentOutOfRangeException(nameof(format)),
    };

    /// <summary>Only full sittings are ranked; the short form stays practice.</summary>
    public bool IsRanked => Format == TestFormat.Full;

    public TimeSpan TimeLimit => Format == TestFormat.Full
        ? TimeSpan.FromMinutes(25)
        : TimeSpan.FromMinutes(12);

    private static int CategoryCount => Enum.GetValues<QuestionCategory>().Length;

    public int ItemsPerCategory => _perDifficulty.Values.Sum();

    public int WeightPerCategory => _perDifficulty.Sum(entry => entry.Key * entry.Value);

    public int ItemCount => ItemsPerCategory * CategoryCount;

    /// <summary>Weighted points available, identical for every sitting of this format.</summary>
    public int MaxWeight => WeightPerCategory * CategoryCount;

    public int DrawnAt(int difficulty) => _perDifficulty.TryGetValue(difficulty, out var count) ? count : 0;

    /// <summary>
    /// The smallest pool that lets a draw avoid everything the previous sitting
    /// used: twice what each cell contributes.
    /// </summary>
    public int PoolNeededFor(int difficulty) => DrawnAt(difficulty) * 2;
}
