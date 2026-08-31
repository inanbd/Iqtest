namespace IqTest.Domain.Questions;

/// <summary>The four reasoning domains the test samples from.</summary>
public enum QuestionCategory
{
    Numerical = 1,
    Verbal = 2,
    Logical = 3,
    Spatial = 4,
}

public static class QuestionCategoryExtensions
{
    public static string Label(this QuestionCategory category) => category switch
    {
        QuestionCategory.Numerical => "Numerical",
        QuestionCategory.Verbal => "Verbal",
        QuestionCategory.Logical => "Logical",
        QuestionCategory.Spatial => "Spatial",
        _ => throw new ArgumentOutOfRangeException(nameof(category)),
    };

    public static string Description(this QuestionCategory category) => category switch
    {
        QuestionCategory.Numerical => "Number series and quantitative reasoning",
        QuestionCategory.Verbal => "Analogies, relations and classification",
        QuestionCategory.Logical => "Deduction, inference and problem solving",
        QuestionCategory.Spatial => "Abstract pattern and matrix reasoning",
        _ => throw new ArgumentOutOfRangeException(nameof(category)),
    };
}
