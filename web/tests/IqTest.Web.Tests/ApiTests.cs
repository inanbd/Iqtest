using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using IqTest.Application.Abstractions;
using IqTest.Domain.Questions;
using Microsoft.Extensions.DependencyInjection;

namespace IqTest.Web.Tests;

[Collection(WebCollection.Name)]
public sealed class ApiTests(WebFactory factory)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private void SkipIfUnavailable() =>
        Skip.IfNot(factory.IsAvailable, $"SQL Server is not reachable: {factory.UnavailableReason}");

    private QuestionPool Pool => factory.Services.GetRequiredService<IQuestionBank>().Pool;

    /// <summary>Builds a payload from a genuine draw of the real bank.</summary>
    private object GenuineSubmission(
        TestFormat format = TestFormat.Full,
        bool allCorrect = true,
        string? name = "Api Tester",
        string? country = "GB",
        string? email = null)
    {
        var sitting = Pool.Draw(TestBlueprint.For(format), random: new Random(Random.Shared.Next()));
        return new
        {
            format = format.ToString(),
            answers = sitting.Select(q => new
            {
                questionId = q.Id,
                selectedIndex = allCorrect ? q.CorrectIndex : (q.CorrectIndex + 1) % q.OptionCount,
            }),
            durationSeconds = 900,
            displayName = name,
            countryCode = country,
            email,
        };
    }

    [SkippableFact]
    public async Task The_country_list_is_served()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var countries = await client.GetFromJsonAsync<List<JsonElement>>("/api/countries", Json);

        Assert.NotNull(countries);
        Assert.True(countries!.Count > 200);
        Assert.Contains(countries, c => c.GetProperty("code").GetString() == "GB");
    }

    [SkippableFact]
    public async Task A_genuine_full_sitting_is_scored_and_ranked()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/attempts", GenuineSubmission());
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<JsonElement>(Json);

        // A perfect sitting scores 136 on both platforms.
        Assert.Equal(136, result.GetProperty("score").GetInt32());
        Assert.Equal(32, result.GetProperty("correct").GetInt32());
        Assert.True(result.GetProperty("isRanked").GetBoolean());
        Assert.Equal(22, result.GetProperty("certificateSlug").GetString()!.Length);

        // The certificate is readable at its own address.
        var slug = result.GetProperty("certificateSlug").GetString()!;
        var certificate = await client.GetFromJsonAsync<JsonElement>($"/api/certificates/{slug}", Json);
        Assert.Equal("Api Tester", certificate.GetProperty("displayName").GetString());
        Assert.Equal("United Kingdom", certificate.GetProperty("country").GetString());
    }

    [SkippableFact]
    public async Task A_submitted_score_field_is_ignored_in_favour_of_the_servers_own()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var sitting = Pool.Draw(TestBlueprint.Full, random: new Random(11));
        var response = await client.PostAsJsonAsync("/api/attempts", new
        {
            format = "Full",
            score = 145,          // Not part of the contract; must be ignored.
            percentile = 99.9,
            answers = sitting.Select(q => new { questionId = q.Id, selectedIndex = (int?)null }),
            durationSeconds = 60,
            displayName = "Claimer",
            countryCode = "US",
        });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<JsonElement>(Json);

        // Every answer was blank, so the server's own number is the floor.
        Assert.Equal(57, result.GetProperty("score").GetInt32());
        Assert.Equal(0, result.GetProperty("correct").GetInt32());
    }

    [SkippableFact]
    public async Task A_sitting_that_is_not_a_real_draw_is_refused()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        // The right number of distinct items, but weighted towards the easy end.
        var answers = new List<object>();
        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            foreach (var difficulty in new[] { 1, 2 })
            {
                answers.AddRange(Pool.Cell(category, difficulty)
                    .Take(4)
                    .Select(q => (object)new { questionId = q.Id, selectedIndex = q.CorrectIndex }));
            }
        }

        var response = await client.PostAsJsonAsync("/api/attempts", new
        {
            format = "Full",
            answers,
            durationSeconds = 900,
            displayName = "Cheat",
            countryCode = "US",
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Equal("invalid_submission", error.GetProperty("type").GetString());
    }

    [SkippableFact]
    public async Task An_unknown_country_is_refused()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/api/attempts", GenuineSubmission(country: "ZZ"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [SkippableFact]
    public async Task The_short_form_is_scored_but_not_ranked()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/api/attempts", GenuineSubmission(TestFormat.Quick));
        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.False(result.GetProperty("isRanked").GetBoolean());
        Assert.Equal(16, result.GetProperty("total").GetInt32());
        Assert.NotEmpty(result.GetProperty("certificateSlug").GetString()!);
    }

    [SkippableFact]
    public async Task An_anonymous_submission_gets_a_certificate_but_no_rank()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/api/attempts", GenuineSubmission(name: null, country: null));
        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.False(result.GetProperty("isRanked").GetBoolean());
        Assert.NotEmpty(result.GetProperty("certificateSlug").GetString()!);
    }

    [SkippableFact]
    public async Task An_unknown_certificate_address_is_a_404()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/api/certificates/{new string('a', 22)}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [SkippableFact]
    public async Task The_board_lists_a_submitted_entry()
    {
        SkipIfUnavailable();
        var client = factory.CreateClient();

        var submission = await client.PostAsJsonAsync(
            "/api/attempts", GenuineSubmission(name: "Board Entry", country: "FR"));
        var created = await submission.Content.ReadFromJsonAsync<JsonElement>(Json);
        var slug = created.GetProperty("certificateSlug").GetString();

        var board = await client.GetFromJsonAsync<JsonElement>("/api/leaderboard", Json);
        var rows = board.GetProperty("rows").EnumerateArray().ToList();

        Assert.Contains(rows, row => row.GetProperty("certificateSlug").GetString() == slug);
        Assert.Contains(rows, row => row.GetProperty("country").GetString() == "France");

        // The country filter narrows it.
        var french = await client.GetFromJsonAsync<JsonElement>("/api/leaderboard?country=FR", Json);
        Assert.All(
            french.GetProperty("rows").EnumerateArray(),
            row => Assert.Equal("FR", row.GetProperty("countryCode").GetString()));
    }
}

[Collection(WebCollection.Name)]
public sealed class PageTests(WebFactory factory)
{
    private void SkipIfUnavailable() =>
        Skip.IfNot(factory.IsAvailable, $"SQL Server is not reachable: {factory.UnavailableReason}");

    [SkippableTheory]
    [InlineData("/")]
    [InlineData("/leaderboard")]
    [InlineData("/about")]
    public async Task The_pages_render(string path)
    {
        SkipIfUnavailable();
        var response = await factory.CreateClient().GetAsync(path);

        response.EnsureSuccessStatusCode();
        Assert.Contains("text/html", response.Content.Headers.ContentType!.ToString());
        Assert.Contains("Cognitive Index", await response.Content.ReadAsStringAsync());
    }

    [SkippableFact]
    public async Task A_test_can_be_started_and_shows_its_first_question()
    {
        SkipIfUnavailable();
        // The default client follows redirects; this test wants to see the one
        // that hands over to the first question.
        var client = factory.CreateClient(new Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false,
        });

        // Razor Pages guard posts with an antiforgery token, so drive the flow
        // the way a browser would.
        var home = await client.GetStringAsync("/");
        var token = System.Text.RegularExpressions.Regex
            .Match(home, """name="__RequestVerificationToken"[^>]*value="([^"]+)""")
            .Groups[1].Value;
        Assert.NotEmpty(token);

        var response = await client.PostAsync("/", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["format"] = "Full",
            ["__RequestVerificationToken"] = token,
        }));

        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        var location = response.Headers.Location!.ToString();
        Assert.StartsWith("/test/", location);

        var question = await client.GetStringAsync(location);
        Assert.Contains("Question 1 of 32", question);
        // The answer key must never reach the browser.
        Assert.DoesNotContain("correctIndex", question, StringComparison.OrdinalIgnoreCase);
    }

    [SkippableFact]
    public async Task A_post_without_an_antiforgery_token_is_rejected()
    {
        SkipIfUnavailable();
        var response = await factory.CreateClient().PostAsync(
            "/", new FormUrlEncodedContent(new Dictionary<string, string> { ["format"] = "Full" }));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [SkippableFact]
    public async Task An_unknown_certificate_page_is_a_404()
    {
        SkipIfUnavailable();
        var response = await factory.CreateClient().GetAsync($"/certificate/{new string('z', 22)}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
