using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;

namespace iet_bi_portal_backend.Modules.Profesores.Models;

/// <summary>CU08: datos editables de un profesor. La cédula (RN-10) no se puede cambiar; la cuenta tiene sus propias operaciones.
/// El trim y el paso de vacíos a null los hace la DB (api.fn_limpiar).</summary>
public class ActualizarProfesorRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string Nombre { get; set; } = string.Empty;

    [Required, StringLength(100, MinimumLength = 2)]
    public string PrimerApellido { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? SegundoApellido { get; set; }

    [MaxLength(20)]
    public string? NumeroCelular { get; set; }

    [Required]
    public DateOnly? FechaNacimiento { get; set; }
}

/// <summary>CU06: los mismos campos + la cédula + la cuenta opcional (RN-05). Sin <see cref="Cuenta"/> el profesor queda
/// sin usuario (no inicia sesión); la cuenta se puede crear o quitar después.</summary>
public class RegistrarProfesorRequest : ActualizarProfesorRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string Cedula { get; set; } = string.Empty;

    public CuentaProfesorRequest? Cuenta { get; set; }
}

/// <summary>Cuenta del profesor: <see cref="IdUsuario"/> vincula un usuario existente; <see cref="Email"/> +
/// <see cref="Contrasena"/> (+ <see cref="Roles"/>, por defecto PROFESOR_REGULAR) crean una nueva. Mezclar las dos
/// formas o no indicar ninguna lo rechaza la DB (PR006).</summary>
public class CuentaProfesorRequest
{
    public Guid? IdUsuario { get; set; }

    [EmailAddress, MaxLength(254)]
    public string? Email { get; set; }

    [MinLength(8), MaxLength(128)]
    public string? Contrasena { get; set; }

    [RolValido]
    public List<string>? Roles { get; set; }

    /// <summary>Lo que se audita: nunca la contraseña.</summary>
    public object ParaLog() => new { IdUsuario, Email, Roles };
}

/// <summary>Profesor tal como lo devuelve academico.fn_admin_*_profesor. Se usa también como respuesta HTTP.
/// No expone el id interno (RP-07). Sin cuenta: <see cref="IdUsuario"/>, <see cref="Email"/> y <see cref="Activo"/>
/// son null y <see cref="Roles"/> está vacío.</summary>
public record ProfesorAdmin(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    DateOnly FechaNacimiento,
    Guid? IdUsuario,
    string? Email,
    bool? Activo,
    string[] Roles);
