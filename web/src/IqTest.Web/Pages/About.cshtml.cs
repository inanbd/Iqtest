using IqTest.Application.Abstractions;
using IqTest.Domain.Questions;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

/// <summary>
/// The same explanation the mobile app carries: how a sitting is assembled,
/// how the score follows, and what it cannot tell you.
/// </summary>
public sealed class AboutModel(IQuestionBank bank) : PageModel
{
    public int PoolSize => bank.Pool.Count;
    public TestBlueprint Full => TestBlueprint.Full;
    public TestBlueprint Quick => TestBlueprint.Quick;
}
