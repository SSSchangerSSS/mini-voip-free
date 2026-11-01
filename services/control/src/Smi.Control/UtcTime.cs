using System.Globalization;
namespace Smi.Control;
public static class UtcTime
{
    // DateTime subtraction does not normalize Local and Utc automatically.
    public static DateTime Parse(string value) => DateTimeOffset.Parse(value,
        CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal).UtcDateTime;
}
