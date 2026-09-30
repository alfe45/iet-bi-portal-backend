using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Auth.Models;

/// <summary>Datos para iniciar sesión.</summary>
public class LoginRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MaxLength(128)]
    public string Contrasena { get; set; } = string.Empty;
}

/// <summary>Datos para renovar el access token usando el refresh token.</summary>
public class RefreshRequest
{
    [Required, MaxLength(200)]
    public string RefreshToken { get; set; } = string.Empty;
}

/// <summary>Datos para cerrar sesión (invalidar el refresh token).</summary>
public class LogoutRequest
{
    [Required, MaxLength(200)]
    public string RefreshToken { get; set; } = string.Empty;
}

/// <summary>Datos para que un usuario autenticado cambie su propia contraseña.</summary>
public class CambiarContrasenaRequest
{
    [Required, MaxLength(128)]
    public string ContrasenaActual { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string ContrasenaNueva { get; set; } = string.Empty;
}

/// <summary>Datos para crear el primer administrador del sistema (ver SetupController).</summary>
public class PrimerAdminRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Contrasena { get; set; } = string.Empty;
}

/// <summary>Resultado de la autenticación.</summary>
public record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken);

/// <summary>Identidad + roles de un usuario ya autenticado, lista para emitir un token.</summary>
public record UsuarioAutenticado(Guid Id, string Email, IReadOnlyList<string> Roles);

/// <summary>Usuario tal como lo devuelve la base de datos para autenticar (incluye el hash: nunca sale por HTTP).</summary>
public record UsuarioAuth(
    Guid Id, string Email, string ContrasenaHash, bool Activo, DateTime? BloqueadoHasta, IReadOnlyList<string> Roles);

/// <summary>Resultado de rotar un refresh token. Estado: ok | invalid | expired | reused.</summary>
public record ResultadoRefresh(string Estado, UsuarioAutenticado? Usuario);

/// <summary>Resultado del login: o hay respuesta con tokens, o un código de error del catálogo.</summary>
public record ResultadoLogin(AuthResponse? Respuesta, string? CodigoError)
{
    public static ResultadoLogin Exito(AuthResponse respuesta) => new(respuesta, null);
    public static ResultadoLogin Fallo(string codigoError) => new(null, codigoError);
}
