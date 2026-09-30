using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Security;

namespace iet_bi_portal_backend.Modules.Usuarios.Models;

/// <summary>CU02: datos para registrar un usuario (nace con PROFESOR_REGULAR).</summary>
public class RegistrarUsuarioRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Contrasena { get; set; } = string.Empty;
}

/// <summary>CU04: nuevo correo del usuario.</summary>
public class ActualizarEmailRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;
}

/// <summary>CU04: nueva contraseña (reseteo por un administrador).</summary>
public class ResetearContrasenaRequest
{
    [Required, MinLength(8), MaxLength(128)]
    public string ContrasenaNueva { get; set; } = string.Empty;
}

/// <summary>CU06: rol a asignar.</summary>
public class RolRequest
{
    [Required, RolValido]
    public string Rol { get; set; } = string.Empty;
}

/// <summary>Usuario tal como lo devuelve auth.fn_*_usuario*. Se usa también como respuesta HTTP (no incluye el hash).</summary>
public record UsuarioAdmin(
    Guid Id,
    string Email,
    bool Activo,
    DateTime? BloqueadoHasta,
    DateTime? UltimoLogin,
    DateTime CreadoEn,
    IReadOnlyList<string> Roles,
    long CantidadSesiones);
