using System.Text;

namespace Smi.Control;

/// <summary>
/// Persian/Arabic digit normalization for extension inputs (spec 10.1, test T03).
/// "۱۰۲" and "١٠٢" both become "102". Any non-digit character after trimming
/// whitespace makes the input invalid — never partially interpreted.
/// Valid output: 3-digit ASCII in range 101..199 ("100" reserved/forbidden).
/// </summary>
public static class DigitNormalizer
{
    public static string? NormalizeInternal(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var trimmed = raw.Trim();
        var sb = new StringBuilder(trimmed.Length);
        foreach (var ch in trimmed)
        {
            if (ch is >= '0' and <= '9')
                sb.Append(ch);
            else if (ch is >= '\u06F0' and <= '\u06F9') // Persian digits ۰..۹
                sb.Append((char)(ch - '\u06F0' + '0'));
            else if (ch is >= '\u0660' and <= '\u0669') // Arabic-Indic digits ٠..٩
                sb.Append((char)(ch - '\u0660' + '0'));
            else
                return null; // letters, signs, separators, direction marks — all rejected
        }

        var ascii = sb.ToString();
        if (ascii.Length != 3 || ascii[0] != '1') return null;
        if (ascii == "100") return null;
        return ascii;
    }
}
