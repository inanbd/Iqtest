namespace IqTest.Domain.Scoring;

/// <summary>
/// The deviation scale itself: mean 100, standard deviation 15.
///
/// Turns a weighted proportion into an index, identically to the Flutter
/// app. The constants are shared with it through <c>shared/questions.json</c>,
/// and a test asserts the two implementations agree.
///
/// Those constants are assumed, not measured: there is no norming sample, so
/// the index is a self-consistent scale rather than a clinical measurement.
/// </summary>
public static class DeviationScale
{
    /// <summary>Assumed mean weighted proportion in the reference population.</summary>
    public const double ReferenceMeanProportion = 0.55;

    /// <summary>Assumed standard deviation of that proportion.</summary>
    public const double ReferenceSdProportion = 0.19;

    public const double ScaleMean = 100;
    public const double ScaleSd = 15;

    /// <summary>The index is clamped here: a short test cannot resolve the tails.</summary>
    public const int MinIndex = 55;
    public const int MaxIndex = 145;

    /// <summary>Maps a weighted proportion (0..1) onto the clamped deviation scale.</summary>
    public static int IndexForProportion(double proportion)
    {
        var z = (proportion - ReferenceMeanProportion) / ReferenceSdProportion;
        var raw = ScaleMean + ScaleSd * z;
        return Math.Clamp((int)Math.Round(raw, MidpointRounding.AwayFromZero), MinIndex, MaxIndex);
    }

    /// <summary>Share of the reference distribution at or below <paramref name="index"/>.</summary>
    public static double PercentileForIndex(int index)
    {
        var z = (index - ScaleMean) / ScaleSd;
        return Math.Clamp(NormalCdf(z) * 100, 0.1, 99.9);
    }

    /// <summary>Standard normal cumulative distribution function.</summary>
    public static double NormalCdf(double z) => 0.5 * (1 + Erf(z / Math.Sqrt(2)));

    /// <summary>Standard normal probability density, used to draw the reference curve.</summary>
    public static double NormalPdf(double z) => Math.Exp(-0.5 * z * z) / Math.Sqrt(2 * Math.PI);

    /// <summary>Abramowitz and Stegun 7.1.26; absolute error below 1.5e-7.</summary>
    private static double Erf(double x)
    {
        const double a1 = 0.254829592;
        const double a2 = -0.284496736;
        const double a3 = 1.421413741;
        const double a4 = -1.453152027;
        const double a5 = 1.061405429;
        const double p = 0.3275911;

        var sign = x < 0 ? -1.0 : 1.0;
        var absX = Math.Abs(x);
        var t = 1.0 / (1.0 + p * absX);
        var y = 1.0 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * Math.Exp(-absX * absX);
        return sign * y;
    }

    /// <summary>Conventional descriptive label for a deviation-scale index.</summary>
    public static string BandFor(int index) => index switch
    {
        >= 130 => "Very superior",
        >= 120 => "Superior",
        >= 110 => "High average",
        >= 90 => "Average",
        >= 80 => "Low average",
        >= 70 => "Borderline",
        _ => "Well below average",
    };
}
