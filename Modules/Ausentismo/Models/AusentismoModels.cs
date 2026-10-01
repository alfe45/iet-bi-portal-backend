using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Ausentismo.Models;

/// <summary>Datos editables de una lección (Profesor Regular CU11). Ausentes y Tardias: cédulas de los estudiantes
/// que faltaron y de los que llegaron tarde (listas vacías = asistieron todos a tiempo); reemplazan las anteriores.
/// Fecha (LE001, PA004), fecha y hora repetidas (LE002), estudiantes no matriculados (LE003) y un estudiante en las
/// dos listas (LE004) los valida la DB.</summary>
public class ModificarLeccionRequest
{
    [Required]
    public DateOnly? Fecha { get; set; }

    [Required]
    public TimeOnly? Hora { get; set; }

    [MaxLength(255)]
    public string? Tema { get; set; }

    [MaxLength(100, ErrorMessage = "No se pueden marcar más de 100 ausentes.")]
    public List<string> Ausentes { get; set; } = [];

    [MaxLength(100, ErrorMessage = "No se pueden marcar más de 100 llegadas tardías.")]
    public List<string> Tardias { get; set; } = [];
}

/// <summary>Profesor Regular CU10: registra una lección de su asignación (año, nivel, número, código) con sus ausentes.</summary>
public class RegistrarLeccionRequest : ModificarLeccionRequest
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }

    [Required, MaxLength(10)]
    public string CodigoAsignatura { get; set; } = string.Empty;
}

/// <summary>Profesor Regular CU11: justificar una ausencia (RN-69).</summary>
public class JustificarAusenciaRequest
{
    [Required, StringLength(255, MinimumLength = 3, ErrorMessage = "La justificación debe tener entre 3 y 255 caracteres.")]
    public string Justificacion { get; set; } = string.Empty;
}

/// <summary>Filtro común: la asignación del profesor autenticado y, opcionalmente, un semestre.</summary>
public class ConsultaAusentismo
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }

    [Required, MaxLength(10)]
    public string CodigoAsignatura { get; set; } = string.Empty;

    [RegularExpression(Semestres.Patron, ErrorMessage = Semestres.Mensaje)]
    public string? Semestre { get; set; }
}

/// <summary>Profesor Regular CU12: lecciones de una asignación, paginadas (de la más reciente a la más antigua).</summary>
public class ConsultaLecciones : ConsultaAusentismo
{
    [Range(1, int.MaxValue, ErrorMessage = "La página debe ser mayor o igual a 1.")]
    public int Pagina { get; set; } = 1;

    [Range(1, 100, ErrorMessage = "El tamaño de página debe estar entre 1 y 100.")]
    public int TamanoPagina { get; set; } = 20;
}

/// <summary>Guía CU05: ausentismo de su sección guía, opcionalmente de un semestre.</summary>
public class ConsultaAusentismoGuia
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }

    [RegularExpression(Semestres.Patron, ErrorMessage = Semestres.Mensaje)]
    public string? Semestre { get; set; }
}

/// <summary>Lección tal como la devuelve academico.fn_profesor_*_leccion*. Ausentes, Justificadas y Tardias son conteos.</summary>
public record Leccion(
    long IdLeccion,
    int Anio,
    int Nivel,
    int Numero,
    string Seccion,
    string CodigoAsignatura,
    string Asignatura,
    DateOnly Fecha,
    TimeOnly Hora,
    string? Tema,
    string Semestre,
    int Ausentes,
    int Justificadas,
    int Tardias);

/// <summary>Ausencia o llegada tardía (Tardia = true) de un estudiante en una lección. Las tardías no se justifican.</summary>
public record Ausencia(string CedulaEstudiante, string NombreEstudiante, bool Tardia, bool Justificada, string? Justificacion);

/// <summary>Detalle de una lección con sus ausentes y llegadas tardías.</summary>
public record LeccionConAusentes(Leccion Leccion, List<Ausencia> Ausentes);

/// <summary>RN-70: ausencias de un estudiante en una asignación contra las lecciones registradas mientras estuvo
/// matriculado; las llegadas tardías van aparte (RN-86). PorcentajeAusentismo es null si no hubo lecciones.</summary>
public record ResumenAusentismo(
    string CedulaEstudiante,
    string NombreEstudiante,
    string EstadoMatricula,
    string CodigoAsignatura,
    string Asignatura,
    string NombreProfesor,
    int Lecciones,
    int Ausencias,
    int Justificadas,
    int Injustificadas,
    int Tardias,
    decimal? PorcentajeAusentismo);
