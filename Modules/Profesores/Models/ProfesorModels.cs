using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Profesores.Models;

/// <summary>CU08: datos editables de un profesor. La cédula (RN-10) y el usuario vinculado no se pueden cambiar.
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

/// <summary>CU06: los mismos campos + la cédula + el usuario existente al que se vincula.</summary>
public class RegistrarProfesorRequest : ActualizarProfesorRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string Cedula { get; set; } = string.Empty;

    [Required]
    public Guid? IdUsuario { get; set; }
}

/// <summary>Profesor tal como lo devuelve academico.fn_admin_*_profesor. Se usa también como respuesta HTTP.
/// No expone el id interno (RP-07).</summary>
public record ProfesorAdmin(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    DateOnly FechaNacimiento,
    Guid IdUsuario,
    string Email);
