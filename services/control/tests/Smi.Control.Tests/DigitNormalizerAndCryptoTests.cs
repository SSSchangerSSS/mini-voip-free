using Smi.Control;
using Xunit;

namespace Smi.Control.Tests;

public class DigitNormalizerTests
{
    [Theory]
    [InlineData("102", "102")]
    [InlineData(" 102 ", "102")]     // trim surrounding spaces
    [InlineData("\u06F1\u06F0\u06F2", "102")]  // ۱۰۲
    [InlineData("\u0661\u0660\u0662", "102")]  // ١٠٢ (Arabic-Indic)
    [InlineData("1\u06F00", "100")]  // normalized to 100 first — rejected below by range rule? no: 100 invalid
    public void Normalize_KnownInputs(string input, string? expected)
    {
        var result = DigitNormalizer.NormalizeInternal(input);
        if (expected == "100") Assert.Null(result); // 100 is out of the allowed 101..199 range
        else Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData("10")]           // too short
    [InlineData("1021")]         // too long
    [InlineData("100")]          // reserved
    [InlineData("abc")]
    [InlineData("10a")]
    [InlineData("1O2")]          // letter O, not zero
    [InlineData("\u200E102")]    // LTR mark hidden in the middle — rejected wholesale
    [InlineData("+102")]
    [InlineData("")]
    [InlineData(null)]
    public void Normalize_RejectsInvalid(string? input)
    {
        Assert.Null(DigitNormalizer.NormalizeInternal(input));
    }
}

public class CryptoTests
{
    [Fact]
    public void PasswordHash_VerifyRoundtrip_AndUniqueSalts()
    {
        var (h1, s1, it1) = Crypto.HashPassword("correct horse battery staple");
        var (h2, s2, _) = Crypto.HashPassword("correct horse battery staple");
        Assert.Equal(Crypto.Pbkdf2Iterations, it1);
        Assert.NotEqual(s1, s2);              // independent random salt
        Assert.NotEqual(h1, h2);
        Assert.True(Crypto.VerifyPassword("correct horse battery staple", h1, s1, it1));
        Assert.False(Crypto.VerifyPassword("wrong", h1, s1, it1));
        Assert.Equal(600_000, it1);           // spec 7.1 — not tunable down silently
    }

    [Fact]
    public void AccessToken_Has256BitEntropy_AndStableHash()
    {
        var t1 = Crypto.NewAccessToken();
        var t2 = Crypto.NewAccessToken();
        Assert.NotEqual(t1, t2);
        Assert.Equal(43, t1.Length);          // 32 bytes → base64url without padding = 43 chars
        Assert.Equal(Crypto.TokenHash(t1), Crypto.TokenHash(t1));
        Assert.NotEqual(Crypto.TokenHash(t1), Crypto.TokenHash(t2));
        Assert.DoesNotContain(t1, Crypto.TokenHash(t1)); // raw token never stored
    }

    [Fact]
    public void SipSecret_MeetsLengthAndCharset()
    {
        var s = Crypto.NewSipSecret();
        Assert.True(s.Length >= 24);
        Assert.All(s, c => Assert.True(char.IsAsciiLetterOrDigit(c)));
    }
}
