namespace iet_bi_portal_backend.Common.Texto;

public static class TextoExtensions
{
    /// <summary>Correo en minúsculas y sin espacios en los extremos.</summary>
    public static string NormalizarEmail(this string email) => email.Trim().ToLowerInvariant();
}
