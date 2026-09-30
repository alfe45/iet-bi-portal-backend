using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Estudiantes.Models;

/// <summary>CU12: datos editables de un estudiante. La cédula no se puede cambiar (RN-10).
/// La edad (RN-01) se valida al matricular, contra el inicio del periodo. El trim y los vacíos a null los hace la DB.</summary>
public class ActualizarEstudianteRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string Nombre { get; set; } = string.Empty;

    [Required, StringLength(100, MinimumLength = 2)]
    public string PrimerApellido { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? SegundoApellido { get; set; }

    [MaxLength(20)]
    public string? NumeroCelular { get; set; }

    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required]
    public DateOnly? FechaNacimiento { get; set; }
}

/// <summary>CU10: los mismos campos + la cédula.</summary>
public class RegistrarEstudianteRequest : ActualizarEstudianteRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string Cedula { get; set; } = string.Empty;
}

/// <summary>Estudiante tal como lo devuelve academico.fn_admin_*_estudiante. Se usa también como respuesta HTTP.
/// No expone el id interno (RP-07).</summary>
public record EstudianteAdmin(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento,
    DateTime FechaRegistro);
