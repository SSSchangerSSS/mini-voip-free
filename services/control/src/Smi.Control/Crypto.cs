using System.Security.Cryptography;
using System.Text;

namespace Smi.Control;

/// <summary>
/// Password/token/secret primitives (spec 7.1, 11.x).
/// - Account passwords: PBKDF2-HMAC-SHA256, independent random salt (>=16 bytes), 600k iterations.
/// - Session tokens: 256-bit CSPRNG, stored only as SHA-256 hex.
/// - SIP secrets: CSPRNG, >= 24 safe ASCII characters.
/// No hand-rolled primitives.
/// </summary>
public static class Crypto
{
    public const int Pbkdf2Iterations = 600_000;
    private const int SaltSize = 16;
    private const int HashSize = 32;

    public static (string Hash, string Salt, int Iterations) HashPassword(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, Pbkdf2Iterations, HashAlgorithmName.SHA256, HashSize);
        return (Convert.ToBase64String(hash), Convert.ToBase64String(salt), Pbkdf2Iterations);
    }

    public static bool VerifyPassword(string password, string storedHashB64, string storedSaltB64, int iterations)
    {
        try
        {
            var salt = Convert.FromBase64String(storedSaltB64);
            var expected = Convert.FromBase64String(storedHashB64);
            var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
            return CryptographicOperations.FixedTimeEquals(actual, expected);
        }
        catch (FormatException)
        {
            return false;
        }
    }

    /// <summary>Opaque access token: 256 bits of entropy, Base64Url. Returned once at login.</summary>
    public static string NewAccessToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        return Base64UrlEncode(bytes);
    }

    public static string TokenHash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))).ToLowerInvariant();

    private const string SipSecretAlphabet = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    public static string NewSipSecret()
    {
        var bytes = RandomNumberGenerator.GetBytes(28);
        var chars = new char[bytes.Length];
        for (var i = 0; i < bytes.Length; i++)
            chars[i] = SipSecretAlphabet[bytes[i] % SipSecretAlphabet.Length];
        return new string(chars); // 28 chars >= 24 required, unambiguous ASCII
    }

    public static string NewId() => Guid.NewGuid().ToString("D");

    private static string Base64UrlEncode(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
