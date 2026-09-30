using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Periodos.Models;

/// <summary>CU16: fechas de los dos semestres. El año no se puede cambiar. El orden de las fechas y
/// las reglas de cierre las valida la DB (PA002, PA004, PA005, PA007, PA008).</summary>
public class ActualizarPeriodoRequest
{
    [Required]
    public DateOnly? InicioSemestreI { get; set; }

    [Required]
    public DateOnly? FinSemestreI { get; set; }

    [Required]
    public DateOnly? InicioSemestreII { get; set; }

    [Required]
    public DateOnly? FinSemestreII { get; set; }
}

/// <summary>CU14: las mismas fechas + el año del periodo.</summary>
public class RegistrarPeriodoRequest : ActualizarPeriodoRequest
{
    [Required]
    public int? Anio { get; set; }
}

/// <summary>Periodo tal como lo devuelve academico.fn_*_periodo*. Se usa también como respuesta HTTP.
/// Estado: PROGRAMADO | EN_CURSO | FINALIZADO. SemestreActual: I_SEMESTRE | II_SEMESTRE | null (fuera de semestre).</summary>
public record PeriodoAcademico(
    int Anio,
    DateOnly InicioSemestreI,
    DateOnly FinSemestreI,
    DateOnly InicioSemestreII,
    DateOnly FinSemestreII,
    string Estado,
    string? SemestreActual);
