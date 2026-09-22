using System.Security.Cryptography;
using System.Text;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Auth.Settings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

/// <summary>
/// Inicialización del sistema. El único propósito de este controller es crear
/// el primer administrador cuando la base de datos todavía no tiene ninguno.
/// </summary>
[ApiController]
[Route("api/setup")]
[EnableRateLimiting("auth")]
public class SetupController : ControllerBase
{
    private readonly AuthService _auth;
    private readonly BootstrapOptions _bootstrap;

    /// <summary> Crea un nuevo SetupController. </summary>
    public SetupController(AuthService auth, IOptions<BootstrapOptions> bootstrap)
    {
        _auth = auth;
        _bootstrap = bootstrap.Value;
    }

    /// <summary> Crea el primer administrador del sistema. </summary>
    /// <param name="request">Los datos del administrador a crear.</param>
    /// <param name="bootstrapToken">El token de bootstrap para autorizar la operación.</param>
    /// <returns>El resultado de la operación.</returns>
    /// <remarks>
    /// [AllowAnonymous] porque todavía no existe ningún usuario con quien autenticarse.
    /// Como protección adicional (más allá de la garantía "solo una vez" que da la base
    /// de datos) se exige un token compartido por header, configurado fuera del código
    /// vía ADMIN_BOOTSTRAP_TOKEN. Así el endpoint no queda abierto a cualquiera en
    /// internet solo por conocer la URL, y quien no trae el token correcto ni se entera
    /// de si ya existe un admin o no.
    /// </remarks>
    [AllowAnonymous]
    [HttpPost("first-admin")]
    public async Task<IActionResult> CreateFirstAdmin(
        BootstrapAdminRequest request,
        [FromHeader(Name = "X-Bootstrap-Token")] string? bootstrapToken)
    {
        if (!IsAuthorized(bootstrapToken))
            return StatusCode(StatusCodes.Status403Forbidden, new { error = "No autorizado." });

        var result = await _auth.BootstrapAdminAsync(request.Email, request.Password);

        return result.Status switch
        {
            BootstrapAdminStatus.Ok => StatusCode(StatusCodes.Status201Created, new
            {
                id = result.UserId,
                email = request.Email.Trim().ToLowerInvariant()
            }),
            BootstrapAdminStatus.AlreadyExists =>
                Conflict(new { error = "El administrador inicial ya fue creado." }),
            BootstrapAdminStatus.EmailTaken =>
                Conflict(new { error = "El correo ya está en uso." }),
            _ => StatusCode(StatusCodes.Status500InternalServerError)
        };
    }

    /// <summary> Verifica si el token de bootstrap proporcionado es válido. </summary>
    /// <param name="providedToken">El token de bootstrap a verificar.</param>
    /// <returns>True si el token es válido, false en caso contrario.</returns>
    private bool IsAuthorized(string? providedToken)
    {
        if (string.IsNullOrEmpty(_bootstrap.Secret) || string.IsNullOrEmpty(providedToken))
            return false;

        var expected = Encoding.UTF8.GetBytes(_bootstrap.Secret);
        var provided = Encoding.UTF8.GetBytes(providedToken);

        // Comparamos en tiempo constante (evita filtrar el token por timing);
        // longitudes distintas ya alcanzan para descartarlo.
        return expected.Length == provided.Length && CryptographicOperations.FixedTimeEquals(expected, provided);
    }
}
