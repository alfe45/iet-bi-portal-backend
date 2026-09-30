using System.Security.Claims;
using Microsoft.IdentityModel.JsonWebTokens;

namespace iet_bi_portal_backend.Common.Security;

public static class ClaimsPrincipalExtensions
{
    /// <summary>Id del usuario desde el claim "sub", o null si falta o no es un Guid.</summary>
    public static Guid? ObtenerIdUsuario(this ClaimsPrincipal usuario) =>
        Guid.TryParse(usuario.FindFirst(JwtRegisteredClaimNames.Sub)?.Value, out var id) ? id : null;
}
