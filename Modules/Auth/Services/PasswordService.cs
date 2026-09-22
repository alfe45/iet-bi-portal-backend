using System.Security.Cryptography;

namespace iet_bi_portal_backend.Security;

public interface IPasswordService
{
    string Hash(string password);
    bool Verify(string password, string storedHash);
    void VerifyDummy(string password);
}

public class PasswordService : IPasswordService
{
    private const string Version = "v1";
    private const int SaltSize = 16;
    private const int KeySize = 32;
    private const int Iterations = 600_000;   // recomendación OWASP para PBKDF2-SHA256

    private readonly string _dummyHash;

    /// <summary> Singleton: este hash falso se calcula una sola vez. </summary>
    public PasswordService() => _dummyHash = Hash("dummy-password-for-timing");

    /// <summary> Crea un hash de la contraseña. </summary>
    public string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var key = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, KeySize);
        return $"{Version}.{Iterations}.{Convert.ToBase64String(salt)}.{Convert.ToBase64String(key)}";
    }

    /// <summary> Verifica si la contraseña coincide con el hash almacenado. </summary>
    public bool Verify(string password, string storedHash)
    {
        var parts = storedHash.Split('.');
        if (parts.Length != 4 || parts[0] != Version || !int.TryParse(parts[1], out var iterations))
            return false;

        byte[] salt, expected;
        try
        {
            salt = Convert.FromBase64String(parts[2]);
            expected = Convert.FromBase64String(parts[3]);
        }
        catch (FormatException) { return false; }

        var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);   // tiempo constante
    }

    /// <summary> Gasta el mismo tiempo que un Verify real, para no revelar si un correo existe. </summary>
    public void VerifyDummy(string password) => Verify(password, _dummyHash);
}