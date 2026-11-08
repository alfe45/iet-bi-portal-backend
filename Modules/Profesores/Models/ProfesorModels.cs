using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;

namespace iet_bi_portal_backend.Modules.Profesores.Models;

/// <summary>Datos editables de un profesor. La cédula (RN-10) no se puede cambiar.
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

/// <summary>CU03: los datos del profesor y, opcionalmente, los cambios de su cuenta, aplicados en una sola transacción
/// (RD-010): si un cambio falla no queda nada guardado. Sin <see cref="Cuenta"/> solo se modifican los datos.</summary>
public class ModificarProfesorRequest : ActualizarProfesorRequest
{
    public ActualizarCuentaProfesorRequest? Cuenta { get; set; }
}

/// <summary>CU03: cambios de la cuenta del profesor. Un campo null no se modifica. <see cref="Roles"/> es el conjunto
/// completo deseado. Si el profesor no tenía cuenta (registrado antes de RN-05), se le crea con estos datos.</summary>
public class ActualizarCuentaProfesorRequest
{
    [EmailAddress, MaxLength(254)]
    public string? Email { get; set; }

    /// <summary>Contraseña nueva (8 a 128); null = no se cambia.</summary>
    [MinLength(8), MaxLength(128)]
    public string? Contrasena { get; set; }

    public bool? Activo { get; set; }

    [RolValido]
    public List<string>? Roles { get; set; }

    /// <summary>Lo que se audita: nunca la contraseña, solo si se restableció.</summary>
    public object ParaLog() => new { Email, Activo, Roles, ContrasenaRestablecida = !string.IsNullOrEmpty(Contrasena) };
}

/// <summary>CU01: los mismos campos + la cédula + la cuenta, obligatoria (RN-05): el profesor nace con su usuario.</summary>
public class RegistrarProfesorRequest : ActualizarProfesorRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string Cedula { get; set; } = string.Empty;

    [Required]
    public CuentaProfesorRequest? Cuenta { get; set; }
}

/// <summary>Cuenta del profesor: <see cref="Email"/> + <see cref="Contrasena"/> (+ <see cref="Roles"/>, por defecto
/// PROFESOR_REGULAR).</summary>
public class CuentaProfesorRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string? Email { get; set; }

    [Required, MinLength(8), MaxLength(128)]
    public string? Contrasena { get; set; }

    [RolValido]
    public List<string>? Roles { get; set; }

    /// <summary>Lo que se audita: nunca la contraseña.</summary>
    public object ParaLog() => new { Email, Roles };
}

/// <summary>Profesor tal como lo devuelve academico.fn_admin_*_profesor. Se usa también como respuesta HTTP.
/// No expone el id interno (RP-07). Un profesor registrado antes de que la cuenta fuera obligatoria puede no tenerla:
/// entonces <see cref="IdUsuario"/>, <see cref="Email"/> y <see cref="Activo"/> son null y <see cref="Roles"/> está vacío.</summary>
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
