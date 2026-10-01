using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Common.Security;

/// <summary>Constantes de los roles. Deben coincidir con el enum api.roles de la base de datos.</summary>
public static class Roles
{
    public const string Admin = "ADMIN";
    public const string ProfesorRegular = "PROFESOR_REGULAR";
    public const string ProfesorCas = "PROFESOR_CAS";
    public const string Guia = "GUIA";
    public const string CoordMonografia = "COORD_MONOGRAFIA";
    public const string CoordCas = "COORD_CAS";

    public static readonly IReadOnlyList<string> Todos =
        [Admin, ProfesorRegular, ProfesorCas, Guia, CoordMonografia, CoordCas];
}

/// <summary>Nombres de claims del JWT.</summary>
public static class AuthClaims
{
    public const string Role = "role";
}

/// <summary>Valida que el texto sea un rol existente (sin distinguir mayúsculas).</summary>
[AttributeUsage(AttributeTargets.Property | AttributeTargets.Parameter)]
public sealed class RolValidoAttribute()
    : ValidationAttribute($"Rol inválido. Valores permitidos: {string.Join(", ", Roles.Todos)}.")
{
    public override bool IsValid(object? value) =>
        value is null || (value is string texto && Roles.Todos.Contains(texto, StringComparer.OrdinalIgnoreCase));
}
