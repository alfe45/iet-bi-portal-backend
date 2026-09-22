using System.Security.Claims;
using Microsoft.IdentityModel.JsonWebTokens;

namespace iet_bi_portal_backend.Modules.Auth.Security;

/// <summary> Extensiones para ClaimsPrincipal. </summary>
public static class ClaimsPrincipalExtensions
{
    /// <summary> Obtiene el ID de usuario del claim "sub" (JWT Registered Claim Name). </summary>
    public static Guid? GetUserId(this ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirst(JwtRegisteredClaimNames.Sub)?.Value, out var id) ? id : null;

    /// <summary> Obtiene el correo electrónico del claim "email" (JWT Registered Claim Name). </summary>
    public static string? GetEmail(this ClaimsPrincipal user) =>
        user.FindFirst(JwtRegisteredClaimNames.Email)?.Value;
}