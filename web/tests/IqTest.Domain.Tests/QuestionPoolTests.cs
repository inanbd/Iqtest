using IqTest.Domain.Attempts;
using IqTest.Domain.Common;
using IqTest.Domain.Questions;

namespace IqTest.Domain.Tests;

public sealed class QuestionPoolTests
{
    /// <summary>A pool shaped like the real one: twice what any blueprint draws.</summary>
    private static QuestionPool BuildPool(int perCell = 4)
    {
        var questions = new List<Question>();
        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            for (var difficulty = 1; difficulty <= 5; difficulty++)
            {
                for (var i = 0; i < perCell; i++)
                {
                    questions.Add(new TextQuestion(
                        $"{category}-{difficulty}-{i}", category, difficulty, "?",
                        ["a", "b", "c", "d"], 0, "x"));
                }
            }
        }
        return new QuestionPool(questions);
    }

    [Fact]
    public void A_pool_cannot_repeat_an_id()
    {
        var duplicate = new TextQuestion("dup", QuestionCategory.Verbal, 1, "?", ["a", "b", "c", "d"], 0, "x");
        var exception = Assert.Throws<DomainException>(() => new QuestionPool([duplicate, duplicate]));
        Assert.Contains("dup", exception.Message);
    }

    [Theory]
    [InlineData(32)]
    [InlineData(16)]
    public void A_draw_matches_the_blueprint_exactly(int expectedCount)
    {
        var blueprint = expectedCount == 32 ? TestBlueprint.Full : TestBlueprint.Quick;
        var pool = BuildPool();

        for (var seed = 0; seed < 20; seed++)
        {
            var sitting = pool.Draw(blueprint, random: new Random(seed));
            Assert.Equal(expectedCount, sitting.Count);

            foreach (var category in Enum.GetValues<QuestionCategory>())
            {
                for (var difficulty = 1; difficulty <= 5; difficulty++)
                {
                    Assert.Equal(
                        blueprint.DrawnAt(difficulty),
                        sitting.Count(q => q.Category == category && q.Difficulty == difficulty));
                }
            }
        }
    }

    [Fact]
    public void Every_draw_offers_the_same_weighted_points()
    {
        var pool = BuildPool();
        for (var seed = 0; seed < 20; seed++)
        {
            Assert.Equal(108, pool.Draw(TestBlueprint.Full, random: new Random(seed)).Sum(q => q.Weight));
            Assert.Equal(56, pool.Draw(TestBlueprint.Quick, random: new Random(seed)).Sum(q => q.Weight));
        }
    }

    [Fact]
    public void A_draw_ramps_from_easiest_to_hardest()
    {
        var sitting = pool_Draw();
        for (var i = 1; i < sitting.Count; i++)
            Assert.True(sitting[i].Difficulty >= sitting[i - 1].Difficulty);

        static IReadOnlyList<Question> pool_Draw() =>
            BuildPool().Draw(TestBlueprint.Full, random: new Random(7));
    }

    [Fact]
    public void Two_consecutive_sittings_share_no_items()
    {
        var pool = BuildPool();
        for (var seed = 0; seed < 20; seed++)
        {
            var first = pool.Draw(TestBlueprint.Full, random: new Random(seed));
            var second = pool.Draw(
                TestBlueprint.Full,
                first.Select(q => q.Id).ToHashSet(),
                new Random(seed + 100));

            Assert.Empty(second.Select(q => q.Id).Intersect(first.Select(q => q.Id)));
        }
    }

    [Fact]
    public void A_draw_still_fills_the_blueprint_when_everything_is_excluded()
    {
        var pool = BuildPool();
        var everything = pool.All.Select(q => q.Id).ToHashSet();

        var sitting = pool.Draw(TestBlueprint.Full, everything, new Random(3));

        // Falls back to repeating rather than returning a short test.
        Assert.Equal(32, sitting.Count);
        Assert.Equal(32, sitting.Select(q => q.Id).Distinct().Count());
        Assert.Equal(108, sitting.Sum(q => q.Weight));
    }

    [Fact]
    public void ValidateSitting_accepts_a_genuine_draw()
    {
        var pool = BuildPool();
        var sitting = pool.Draw(TestBlueprint.Full, random: new Random(1));

        var validated = pool.ValidateSitting(sitting.Select(q => q.Id).ToList(), TestBlueprint.Full);

        Assert.Equal(sitting.Select(q => q.Id), validated.Select(q => q.Id));
    }

    [Fact]
    public void ValidateSitting_rejects_the_wrong_number_of_items()
    {
        var pool = BuildPool();
        var short_ = pool.Draw(TestBlueprint.Full, random: new Random(1)).Take(31).Select(q => q.Id).ToList();

        var exception = Assert.Throws<InvalidSubmissionException>(
            () => pool.ValidateSitting(short_, TestBlueprint.Full));
        Assert.Contains("32 items", exception.Message);
    }

    [Fact]
    public void ValidateSitting_rejects_a_repeated_item()
    {
        var pool = BuildPool();
        var ids = pool.Draw(TestBlueprint.Full, random: new Random(1)).Select(q => q.Id).ToList();
        ids[31] = ids[0];

        Assert.Throws<InvalidSubmissionException>(() => pool.ValidateSitting(ids, TestBlueprint.Full));
    }

    [Fact]
    public void ValidateSitting_rejects_a_sitting_skewed_towards_the_easy_end()
    {
        var pool = BuildPool();

        // The right number of distinct items, but the wrong difficulty profile:
        // exactly the shape a forged submission would take.
        var ids = new List<string>();
        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            ids.AddRange(pool.Cell(category, 1).Take(4).Select(q => q.Id));
            ids.AddRange(pool.Cell(category, 2).Take(4).Select(q => q.Id));
        }

        var exception = Assert.Throws<InvalidSubmissionException>(
            () => pool.ValidateSitting(ids, TestBlueprint.Full));
        Assert.Contains("difficulty", exception.Message);
    }

    [Fact]
    public void ValidateSitting_rejects_an_unknown_item()
    {
        var pool = BuildPool();
        var ids = pool.Draw(TestBlueprint.Full, random: new Random(1)).Select(q => q.Id).ToList();
        ids[0] = "does-not-exist";

        Assert.Throws<InvalidSubmissionException>(() => pool.ValidateSitting(ids, TestBlueprint.Full));
    }

    [Fact]
    public void ShortfallsFor_flags_a_pool_that_cannot_avoid_repeats()
    {
        Assert.Empty(BuildPool().ShortfallsFor(TestBlueprint.Full));
        // Exactly enough to serve one sitting, but not two without repeating.
        Assert.NotEmpty(BuildPool(perCell: 2).ShortfallsFor(TestBlueprint.Full));
        // Not even enough for one.
        Assert.NotEmpty(BuildPool(perCell: 1).ShortfallsFor(TestBlueprint.Full));
    }
}

public sealed class TestBlueprintTests
{
    [Fact]
    public void The_full_sitting_is_32_items_and_108_points()
    {
        Assert.Equal(8, TestBlueprint.Full.ItemsPerCategory);
        Assert.Equal(27, TestBlueprint.Full.WeightPerCategory);
        Assert.Equal(32, TestBlueprint.Full.ItemCount);
        Assert.Equal(108, TestBlueprint.Full.MaxWeight);
        Assert.True(TestBlueprint.Full.IsRanked);
        Assert.Equal(TimeSpan.FromMinutes(25), TestBlueprint.Full.TimeLimit);
    }

    [Fact]
    public void The_short_form_is_16_items_56_points_and_is_never_ranked()
    {
        Assert.Equal(16, TestBlueprint.Quick.ItemCount);
        Assert.Equal(56, TestBlueprint.Quick.MaxWeight);
        Assert.False(TestBlueprint.Quick.IsRanked);
        // It skips the easiest band entirely.
        Assert.Equal(0, TestBlueprint.Quick.DrawnAt(1));
    }
}

public sealed class ParticipantTests
{
    private static Participant Create(string name = "Ada", string country = "GB", string? email = null)
        => Participant.Create(Guid.NewGuid(), name, country, email, DateTimeOffset.UtcNow);

    [Fact]
    public void Trims_and_normalises_what_it_is_given()
    {
        var participant = Create("  Ada  ", "gb", "  ADA@Example.com ");
        Assert.Equal("Ada", participant.DisplayName);
        Assert.Equal("GB", participant.CountryCode);
        Assert.Equal("ADA@Example.com", participant.Email);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Requires_a_name(string name)
        => Assert.Throws<DomainException>(() => Create(name));

    [Fact]
    public void Caps_the_name_length()
        => Assert.Throws<DomainException>(() => Create(new string('a', 41)));

    [Theory]
    [InlineData("")]
    [InlineData("GBR")]
    [InlineData("1")]
    public void Requires_a_two_letter_country(string country)
        => Assert.Throws<DomainException>(() => Create(country: country));

    [Fact]
    public void Treats_a_blank_email_as_absent()
        => Assert.Null(Create(email: "   ").Email);

    [Theory]
    [InlineData("not-an-email")]
    [InlineData("no@domain")]
    [InlineData("two@@at.com")]
    public void Rejects_an_obviously_wrong_email(string email)
        => Assert.Throws<DomainException>(() => Create(email: email));
}

public sealed class CertificateSlugTests
{
    [Fact]
    public void Is_22_url_safe_characters()
    {
        var slug = CertificateSlug.NewSlug().Value;
        Assert.Equal(22, slug.Length);
        Assert.DoesNotContain('+', slug);
        Assert.DoesNotContain('/', slug);
        Assert.DoesNotContain('=', slug);
    }

    [Fact]
    public void Is_stable_for_a_given_id_and_distinct_between_ids()
    {
        var id = Guid.NewGuid();
        Assert.Equal(CertificateSlug.FromGuid(id), CertificateSlug.FromGuid(id));
        Assert.NotEqual(CertificateSlug.NewSlug(), CertificateSlug.NewSlug());
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("too-short")]
    [InlineData("has spaces in it here!!")]
    public void Refuses_anything_that_is_not_an_address(string? value)
        => Assert.False(CertificateSlug.TryParse(value, out _));

    [Fact]
    public void Round_trips_a_real_address()
    {
        var slug = CertificateSlug.NewSlug();
        Assert.True(CertificateSlug.TryParse(slug.Value, out var parsed));
        Assert.Equal(slug, parsed);
    }
}
