using IqTest.Domain.Common;

namespace IqTest.Domain.Questions;

/// <summary>
/// The item pool, and the draw that turns it into one sitting.
///
/// Mirrors the Dart <c>QuestionBank</c>: every domain holds at least twice
/// what any blueprint draws from a cell, and that surplus is what lets a draw
/// avoid everything the previous sitting used.
/// </summary>
public sealed class QuestionPool
{
    private readonly IReadOnlyDictionary<string, Question> _byId;
    private readonly IReadOnlyDictionary<(QuestionCategory, int), IReadOnlyList<Question>> _cells;

    public QuestionPool(IEnumerable<Question> questions)
    {
        var all = questions.ToList();

        var duplicate = all.GroupBy(q => q.Id).FirstOrDefault(g => g.Count() > 1);
        if (duplicate is not null)
            throw new DomainException($"The pool repeats the id '{duplicate.Key}'.");

        All = all;
        _byId = all.ToDictionary(q => q.Id);
        _cells = all
            .GroupBy(q => (q.Category, q.Difficulty))
            .ToDictionary(g => g.Key, g => (IReadOnlyList<Question>)g.ToList());
    }

    public IReadOnlyList<Question> All { get; }

    public int Count => All.Count;

    public Question this[string id] => _byId.TryGetValue(id, out var question)
        ? question
        : throw new InvalidSubmissionException($"No item is called '{id}'.");

    public bool TryGet(string id, out Question question) => _byId.TryGetValue(id, out question!);

    /// <summary>The items in one (domain, difficulty) cell of the pool.</summary>
    public IReadOnlyList<Question> Cell(QuestionCategory category, int difficulty) =>
        _cells.TryGetValue((category, difficulty), out var cell) ? cell : [];

    /// <summary>
    /// Builds one sitting to <paramref name="blueprint"/>, ordered easiest to
    /// hardest with the domains interleaved.
    ///
    /// Items in <paramref name="avoid"/> — normally everything the previous
    /// sitting used — are held back and drawn only if a cell would otherwise
    /// come up short.
    /// </summary>
    public IReadOnlyList<Question> Draw(
        TestBlueprint blueprint,
        IReadOnlySet<string>? avoid = null,
        Random? random = null)
    {
        var rng = random ?? Random.Shared;
        avoid ??= new HashSet<string>();
        var picked = new List<Question>();

        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            foreach (var (difficulty, count) in blueprint.PerDifficulty)
            {
                var candidates = Cell(category, difficulty).OrderBy(_ => rng.Next()).ToList();
                var fresh = candidates.Where(q => !avoid.Contains(q.Id));
                var seen = candidates.Where(q => avoid.Contains(q.Id));
                picked.AddRange(fresh.Concat(seen).Take(count));
            }
        }

        return picked
            .OrderBy(_ => rng.Next())
            .OrderBy(q => q.Difficulty)
            .ToList();
    }

    /// <summary>
    /// Checks that a set of item ids is a sitting this pool could have issued.
    ///
    /// The mobile app draws its own sitting offline, so a submission from it
    /// names the items it used. Without this check someone could submit
    /// thirty-two of the easiest items and call it a full test.
    /// </summary>
    public IReadOnlyList<Question> ValidateSitting(IReadOnlyList<string> questionIds, TestBlueprint blueprint)
    {
        ArgumentNullException.ThrowIfNull(questionIds);

        if (questionIds.Count != blueprint.ItemCount)
            throw new InvalidSubmissionException(
                $"A {blueprint.Format.ToString().ToLowerInvariant()} sitting has {blueprint.ItemCount} items, not {questionIds.Count}.");

        if (questionIds.Distinct().Count() != questionIds.Count)
            throw new InvalidSubmissionException("A sitting cannot repeat an item.");

        var questions = questionIds.Select(id => this[id]).ToList();

        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            for (var difficulty = 1; difficulty <= 5; difficulty++)
            {
                var expected = blueprint.DrawnAt(difficulty);
                var actual = questions.Count(q => q.Category == category && q.Difficulty == difficulty);
                if (actual != expected)
                    throw new InvalidSubmissionException(
                        $"A {blueprint.Format.ToString().ToLowerInvariant()} sitting takes {expected} {category.Label().ToLowerInvariant()} " +
                        $"item(s) at difficulty {difficulty}, but this one has {actual}.");
            }
        }

        return questions;
    }

    /// <summary>
    /// Whether the pool can serve a blueprint twice over, which is what the
    /// no-repeat guarantee rests on.
    /// </summary>
    public IReadOnlyList<string> ShortfallsFor(TestBlueprint blueprint)
    {
        var problems = new List<string>();
        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            foreach (var (difficulty, count) in blueprint.PerDifficulty)
            {
                var available = Cell(category, difficulty).Count;
                if (available < count)
                    problems.Add($"{category} difficulty {difficulty}: needs {count}, pool has {available}.");
                else if (available < blueprint.PoolNeededFor(difficulty))
                    problems.Add($"{category} difficulty {difficulty}: a repeat sitting cannot avoid the last one ({available} of {blueprint.PoolNeededFor(difficulty)}).");
            }
        }
        return problems;
    }
}
