using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.JsonWebTokens;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("auth")]
public class AuthController : ControllerBase
{
    private readonly AuthService _auth;

    public AuthController(AuthService auth) => _auth = auth;

    /// <summary> Registra un nuevo usuario con rol PROFESOR. 
    /// Devuelve 201 Created con el access token y refresh token si se creó correctamente, 
    /// o 409 Conflict si el correo ya está en uso. </summary>
    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest request)
    {
        var result = await _auth.RegisterAsync(request.Email, request.Password, GetClientInfo());

        return result is null
            ? Conflict(new { error = "No se pudo completar el registro. Verifica los datos o intenta iniciar sesión." })
            : StatusCode(StatusCodes.Status201Created, result);
    }

    /// <summary> Inicia sesión con correo y contraseña. 
    /// Devuelve 200 OK con el access token y refresh token si las credenciales son correctas, 
    /// o 401 Unauthorized si no lo son. </summary>
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var result = await _auth.LoginAsync(request.Email, request.Password, GetClientInfo());

        return result is null
            ? Unauthorized(new { error = "Credenciales inválidas." })
            : Ok(result);
    }

    /// <summary> Renueva el access token usando el refresh token. 
    /// Devuelve 200 OK con el nuevo access token y refresh token si la operación es exitosa,
    /// o 401 Unauthorized si el refresh token es inválido o ha expirado. </summary>
    [AllowAnonymous]
    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh(RefreshRequest request)
    {
        var result = await _auth.RefreshAsync(request.RefreshToken, GetClientInfo());

        return result is null
            ? Unauthorized(new { error = "Sesión inválida o expirada. Inicia sesión de nuevo." })
            : Ok(result);
    }

    /// <summary> Cierra la sesión del usuario. </summary>
    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutRequest request)
    {
        await _auth.LogoutAsync(request.RefreshToken);
        return NoContent();
    }

    /// <summary> Cierra todas las sesiones del usuario. </summary>
    [Authorize]
    [HttpPost("logout-all")]
    public async Task<IActionResult> LogoutAll()
    {
        if (User.GetUserId() is not { } userId) return Unauthorized();

        await _auth.LogoutAllAsync(userId);
        return NoContent();
    }

    /// <summary> Cambia la contraseña del usuario. </summary>
    [Authorize]
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request)
    {
        if (User.GetUserId() is not { } userId) return Unauthorized();

        var ok = await _auth.ChangePasswordAsync(userId, request.CurrentPassword, request.NewPassword);

        return ok
            ? NoContent()
            : BadRequest(new { error = "La contraseña actual es incorrecta." });
    }

    /// <summary> Endpoint de prueba para verificar que el JWT funciona. 
    /// Cualquier usuario autenticado, sin importar cuáles roles tenga, puede consultar su propia identidad. 
    /// Devuelve TODOS los roles del usuario. </summary>
    [Authorize]
    [HttpGet("me")]
    public IActionResult Me() => Ok(new
    {
        id = User.GetUserId(),
        email = User.FindFirst(JwtRegisteredClaimNames.Email)?.Value,
        roles = User.FindAll(AuthClaims.Role).Select(c => c.Value).ToArray()
    });


    /// <summary> Obtiene la información del cliente. </summary>
    private ClientInfo GetClientInfo()
    {
        var userAgent = Request.Headers.UserAgent.ToString();
        if (userAgent.Length > 300) userAgent = userAgent[..300];
        return new ClientInfo(HttpContext.Connection.RemoteIpAddress?.ToString(), userAgent);
    }
}
