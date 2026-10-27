using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;

namespace iet_bi_portal_backend.Modules.Usuarios.Models;

/// <summary>Usuario sin perfil (administrador inicial y pruebas): datos para registrar un usuario (nace con PROFESOR_REGULAR).</summary>
public class RegistrarUsuarioRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Contrasena { get; set; } = string.Empty;
}

/// <summary>CU08 (cuenta del profesor): nuevo correo del usuario.</summary>
public class ActualizarEmailRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;
}

/// <summary>CU08 (cuenta del profesor): nueva contraseña (reseteo por un administrador).</summary>
public class ResetearContrasenaRequest
{
    [Required, MinLength(8), MaxLength(128)]
    public string ContrasenaNueva { get; set; } = string.Empty;
}

/// <summary>CU08 (cuenta del profesor): rol a asignar.</summary>
public class RolRequest
{
    [Required, RolValido]
    public string Rol { get; set; } = string.Empty;
}

/// <summary>CU07 (cuenta del profesor): listado con búsqueda (correo, cédula o nombre del profesor) y filtro opcional por rol.</summary>
public class ConsultaUsuarios : ConsultaConBusqueda
{
    [RolValido]
    public string? Rol { get; set; }
}

/// <summary>Usuario tal como lo devuelve auth.fn_*_usuario*. Se usa también como respuesta HTTP (no incluye el hash).
/// CedulaProfesor/NombreProfesor: perfil de profesor vinculado, o null si no tiene.</summary>
public record UsuarioAdmin(
    Guid Id,
    string Email,
    bool Activo,
    DateTime? BloqueadoHasta,
    DateTime? UltimoLogin,
    DateTime CreadoEn,
    IReadOnlyList<string> Roles,
    long CantidadSesiones,
    string? CedulaProfesor,
    string? NombreProfesor);
