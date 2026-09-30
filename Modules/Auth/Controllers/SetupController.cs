using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Auth.Settings;
using iet_bi_portal_backend.Modules.Errors;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[Route("api/setup")]
[EnableRateLimiting("auth")]
public class SetupController(AuthService auth, IOptions<BootstrapOptions> bootstrap) : ApiControllerBase
{
    private readonly BootstrapOptions _bootstrap = bootstrap.Value;

    /// <summary>Crea el primer administrador (una sola vez). 201; 403 (AU009) token inválido;
    /// 409 (AU001) ya existe; 409 (TA001) correo en uso.</summary>
    [AllowAnonymous]
    [HttpPost("primer-admin")]
    public async Task<IActionResult> CrearPrimerAdmin(
        PrimerAdminRequest request,
        [FromHeader(Name = "X-Bootstrap-Token")] string? bootstrapToken)
    {
        if (!EsAutorizado(bootstrapToken))
            return this.ApiError("AU009");

        var (id, email) = await auth.CrearPrimerAdminAsync(request.Email, request.Contrasena);
        return StatusCode(StatusCodes.Status201Created, new { id, email });
    }

    private bool EsAutorizado(string? tokenRecibido)
    {
        if (string.IsNullOrEmpty(_bootstrap.Secret) || string.IsNullOrEmpty(tokenRecibido))
            return false;

        var esperado = Encoding.UTF8.GetBytes(_bootstrap.Secret);
        var recibido = Encoding.UTF8.GetBytes(tokenRecibido);

        return esperado.Length == recibido.Length && CryptographicOperations.FixedTimeEquals(esperado, recibido);
    }
}
