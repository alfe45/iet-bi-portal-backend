using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Auth.Models;

/// <summary> Datos para registrar un nuevo usuario. </summary>
public class RegisterRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

/// <summary> Datos para iniciar sesión. </summary>
public class LoginRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

/// <summary> Datos para renovar el access token usando el refresh token. </summary>
public class RefreshRequest
{
    [Required, MaxLength(200)]
    public string RefreshToken { get; set; } = string.Empty;
}

/// <summary> Datos para cerrar sesión (invalidar el refresh token). </summary>
public class LogoutRequest
{
    [Required, MaxLength(200)]
    public string RefreshToken { get; set; } = string.Empty;
}

/// <summary> Datos para cambiar la contraseña de un usuario autenticado. </summary>
public class ChangePasswordRequest
{
    [Required, MaxLength(128)]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string NewPassword { get; set; } = string.Empty;
}

/// <summary>Datos para crear el primer administrador del sistema (ver SetupController).</summary>
public class BootstrapAdminRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

/// <summary> Resultado de la autenticación. </summary>
public record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken);

/// <summary> Información del cliente que inicia sesión o renueva tokens. </summary>
public record ClientInfo(string? Ip, string? UserAgent);

/// <summary>Identidad + roles de un usuario ya autenticado, lista para emitir un token.</summary>
public record AuthenticatedUser(Guid Id, string Email, IReadOnlyList<string> Roles);

/// <summary> Registro de usuario obtenido de la base de datos. </summary>
public record UserRecord(Guid Id, string Email, string PasswordHash, bool IsActive, DateTime? LockoutUntil, IReadOnlyList<string> Roles);

/// <summary> Resultado de rotar un refresh token. </summary>
public record RotateResult(string Status, AuthenticatedUser? User);
