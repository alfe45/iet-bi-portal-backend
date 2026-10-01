using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Asignaciones.Models;

/// <summary>CU30: asignar a un profesor una asignatura en una sección (año, nivel, número).
/// Nivel de la asignatura (AS005), rol del profesor (AD002) y duplicados (AD001) los valida la DB.</summary>
public class RegistrarAsignacionRequest
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }

    [Required, MaxLength(10)]
    public string CodigoAsignatura { get; set; } = string.Empty;

    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaProfesor { get; set; } = string.Empty;
}

/// <summary>CU32: reemplazar al profesor de una asignación (la asignación y sus registros se conservan).</summary>
public class CambiarProfesorRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaProfesorNuevo { get; set; } = string.Empty;
}

/// <summary>CU31: listado paginado; todos los filtros son opcionales.</summary>
public class ConsultaAsignaciones : ConsultaPaginada
{
    public int? Anio { get; set; }

    [Range(10, 11, ErrorMessage = "El nivel debe ser 10 u 11.")]
    public int? Nivel { get; set; }

    public int? Numero { get; set; }

    [MaxLength(10)]
    public string? CodigoAsignatura { get; set; }

    [MaxLength(20)]
    public string? CedulaProfesor { get; set; }
}

/// <summary>Asignación tal como la devuelve academico.fn_*_asignaciones. Se usa también como respuesta HTTP.
/// Seccion: "10-1".</summary>
public record Asignacion(
    int Anio,
    int Nivel,
    int Numero,
    string Seccion,
    string CodigoAsignatura,
    string Asignatura,
    string CedulaProfesor,
    string NombreProfesor);
