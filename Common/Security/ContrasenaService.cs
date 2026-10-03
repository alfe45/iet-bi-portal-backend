using System.Security.Cryptography;

namespace iet_bi_portal_backend.Common.Security;

public interface IContrasenaService
{
    string Hashear(string contrasena);
    bool Verificar(string contrasena, string hashGuardado);
    void VerificarDummy(string contrasena);
}

public class ContrasenaService : IContrasenaService
{
    private const string Version = "v1";
    private const int TamanoSal = 16;
    private const int TamanoClave = 32;
    private const int Iteraciones = 600_000;   // recomendación OWASP para PBKDF2-SHA256

    private readonly string _hashDummy;

    /// <summary>Singleton: el hash falso se calcula una sola vez.</summary>
    public ContrasenaService() => _hashDummy = Hashear("dummy-password-for-timing");

    public string Hashear(string contrasena)
    {
        var sal = RandomNumberGenerator.GetBytes(TamanoSal);
        var clave = Rfc2898DeriveBytes.Pbkdf2(contrasena, sal, Iteraciones, HashAlgorithmName.SHA256, TamanoClave);
        return $"{Version}.{Iteraciones}.{Convert.ToBase64String(sal)}.{Convert.ToBase64String(clave)}";
    }

    public bool Verificar(string contrasena, string hashGuardado)
    {
        var partes = hashGuardado.Split('.');
        if (partes.Length != 4 || partes[0] != Version || !int.TryParse(partes[1], out var iteraciones))
            return false;

        byte[] sal, esperada;
        try
        {
            sal = Convert.FromBase64String(partes[2]);
            esperada = Convert.FromBase64String(partes[3]);
        }
        catch (FormatException) { return false; }

        var actual = Rfc2898DeriveBytes.Pbkdf2(contrasena, sal, iteraciones, HashAlgorithmName.SHA256, esperada.Length);
        return CryptographicOperations.FixedTimeEquals(actual, esperada);   // tiempo constante
    }

    /// <summary>Gasta el mismo tiempo que un Verificar real, para no revelar si un correo existe.</summary>
    public void VerificarDummy(string contrasena) => Verificar(contrasena, _hashDummy);
}
