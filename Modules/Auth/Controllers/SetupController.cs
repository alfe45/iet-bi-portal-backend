using System.Security.Cryptography;
using System.Text;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Auth.Settings;
using iet_bi_portal_backend.Modules.Errors;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[ApiController]
[Route("api/setup")]
[EnableRateLimiting("auth")]
public class SetupController : ControllerBase
{
    private readonly AuthService _auth;
    private readonly BootstrapOptions _bootstrap;

    public SetupController(AuthService auth, IOptions<BootstrapOptions> bootstrap)
    {
        _auth = auth;
        _bootstrap = bootstrap.Value;
    }

    [AllowAnonymous]
    [HttpPost("first-admin")]
    public async Task<IActionResult> CreateFirstAdmin(
    BootstrapAdminRequest request,
    [FromHeader(Name = "X-Bootstrap-Token")] string? bootstrapToken)
    {
        if (!IsAuthorized(bootstrapToken))
            return this.ApiError("AU009");

        // Si ya existe el admin inicial o el correo está en uso, la excepción
        // sube desde la DB (AU001/TA001) y GlobalExceptionHandler la traduce.
        var userId = await _auth.BootstrapAdminAsync(request.Email, request.Password);

        return StatusCode(StatusCodes.Status201Created, new
        {
            id = userId,
            email = request.Email.Trim().ToLowerInvariant()
        });
    }

    private bool IsAuthorized(string? providedToken)
    {
        if (string.IsNullOrEmpty(_bootstrap.Secret) || string.IsNullOrEmpty(providedToken))
            return false;

        var expected = Encoding.UTF8.GetBytes(_bootstrap.Secret);
        var provided = Encoding.UTF8.GetBytes(providedToken);

        return expected.Length == provided.Length && CryptographicOperations.FixedTimeEquals(expected, provided);
    }
}