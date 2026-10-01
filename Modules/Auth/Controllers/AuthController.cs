using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Errors;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[Route("api/auth")]
[EnableRateLimiting("auth")]
public class AuthController(AuthService auth) : ApiControllerBase
{
    /// <summary>Inicia sesión. 200 con tokens; 401 (AU006) credenciales inválidas; 403 (AU014/AU015) cuenta desactivada o bloqueada
    /// (sin evaluar la contraseña: así el bloqueo no sirve para adivinarla).</summary>
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var resultado = await auth.LoginAsync(request.Email, request.Contrasena, Cliente);

        return resultado.Respuesta is { } respuesta
            ? Ok(respuesta)
            : this.ApiError(resultado.CodigoError!);
    }

    /// <summary>Cierra la sesión del refresh token enviado. Siempre 204 (no revela si el token existía).</summary>
    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutRequest request)
    {
        await auth.LogoutAsync(request.RefreshToken, Cliente);
        return NoContent();
    }

    /// <summary>Renueva el access token con el refresh token. 200 con tokens nuevos, o 401 (AU007).</summary>
    [AllowAnonymous]
    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh(RefreshRequest request)
    {
        var resultado = await auth.RefreshAsync(request.RefreshToken, Cliente);
        return resultado is null ? this.ApiError("AU007") : Ok(resultado);
    }

    /// <summary>Cierra todas las sesiones del usuario autenticado.</summary>
    [Authorize]
    [HttpPost("logout-all")]
    public async Task<IActionResult> LogoutAll()
    {
        await auth.LogoutAllAsync(ActorId);
        return NoContent();
    }

    /// <summary>Cambia la contraseña propia. 204; 400 (AU008) si la contraseña actual es incorrecta.</summary>
    [Authorize]
    [HttpPost("cambiar-contrasena")]
    public async Task<IActionResult> CambiarContrasena(CambiarContrasenaRequest request)
    {
        var ok = await auth.CambiarContrasenaAsync(ActorId, request.ContrasenaActual, request.ContrasenaNueva);
        return ok ? NoContent() : this.ApiError("AU008");
    }
}
