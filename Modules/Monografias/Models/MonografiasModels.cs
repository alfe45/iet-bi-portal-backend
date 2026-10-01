using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Monografias.Models;

/// <summary>Valores del enum academico.estado_monografia (deben coincidir con la DB).</summary>
public static class EstadosMonografia
{
    public const string Patron = "(?i)^(CAPACITACION|INVESTIGACION|TERMINADA)$";
    public const string Mensaje = "El estado debe ser CAPACITACION, INVESTIGACION o TERMINADA.";
}

/// <summary>Administrador CU34: asigna el estudiante a un coordinador en una materia (RN-78). Anio: año de la matrícula de
/// nivel 10 del estudiante (MO004). Materia SUPERIOR o MEDIO (MO002), coordinador con COORD_MONOGRAFIA (MO005), grupo de
/// hasta 5 (MO003) y una monografía por estudiante (MO001) los valida la DB.</summary>
public class RegistrarMonografiaRequest
{
    [Required]
    public int? Anio { get; set; }

    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaEstudiante { get; set; } = string.Empty;

    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaCoordinador { get; set; } = string.Empty;

    [Required, MaxLength(10)]
    public string CodigoAsignatura { get; set; } = string.Empty;
}

/// <summary>Administrador CU36: cambia coordinador y/o materia; conserva estado, seguimiento y reportes.</summary>
public class ModificarMonografiaRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaCoordinador { get; set; } = string.Empty;

    [Required, MaxLength(10)]
    public string CodigoAsignatura { get; set; } = string.Empty;
}

/// <summary>Administrador CU35: filtros opcionales (año de inicio = año de su nivel 10).</summary>
public class ConsultaMonografias : ConsultaPaginada
{
    public int? AnioInicio { get; set; }

    [RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string? CedulaCoordinador { get; set; }

    [MaxLength(10)]
    public string? CodigoAsignatura { get; set; }

    [RegularExpression(EstadosMonografia.Patron, ErrorMessage = EstadosMonografia.Mensaje)]
    public string? Estado { get; set; }
}

/// <summary>Coordinador CU01: filtros opcionales de mis monografías.</summary>
public class ConsultaMisMonografias
{
    public int? AnioInicio { get; set; }

    [RegularExpression(EstadosMonografia.Patron, ErrorMessage = EstadosMonografia.Mensaje)]
    public string? Estado { get; set; }
}

/// <summary>Coordinador CU02 (RN-79).</summary>
public class CambiarEstadoMonografiaRequest
{
    [Required, RegularExpression(EstadosMonografia.Patron, ErrorMessage = EstadosMonografia.Mensaje)]
    public string Estado { get; set; } = string.Empty;
}

/// <summary>Coordinador CU03: Fecha opcional (por defecto hoy); no futura ni anterior al inicio de la monografía (MO006).</summary>
public class RegistrarSeguimientoRequest
{
    public DateOnly? Fecha { get; set; }

    [Required, StringLength(1000, MinimumLength = 3, ErrorMessage = "La observación debe tener entre 3 y 1000 caracteres.")]
    public string Observacion { get; set; } = string.Empty;
}

/// <summary>Coordinador CU04.</summary>
public class ModificarSeguimientoRequest
{
    [Required]
    public DateOnly? Fecha { get; set; }

    [Required, StringLength(1000, MinimumLength = 3, ErrorMessage = "La observación debe tener entre 3 y 1000 caracteres.")]
    public string Observacion { get; set; } = string.Empty;
}

/// <summary>Coordinador CU05: observaciones del semestre para el guía (RN-81).</summary>
public class ReporteMonografiaRequest
{
    [Required, StringLength(1000, MinimumLength = 3, ErrorMessage = "Las observaciones deben tener entre 3 y 1000 caracteres.")]
    public string Observaciones { get; set; } = string.Empty;
}

/// <summary>Guía CU07: su sección guía.</summary>
public class ConsultaSeccionGuia
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }
}

/// <summary>Guía CU06: su sección guía en un semestre.</summary>
public class ConsultaReportesGuia : ConsultaSeccionGuia
{
    [Required, RegularExpression(Semestres.Patron, ErrorMessage = Semestres.Mensaje)]
    public string Semestre { get; set; } = string.Empty;
}

/// <summary>Monografía de un estudiante. AnioInicio: año de su nivel 10; AnioActual y SeccionActual: su última matrícula.</summary>
public record Monografia(
    string CedulaEstudiante,
    string NombreEstudiante,
    int AnioInicio,
    int AnioActual,
    string SeccionActual,
    string CedulaCoordinador,
    string NombreCoordinador,
    string CodigoAsignatura,
    string Asignatura,
    string Estado,
    int Seguimientos,
    DateOnly? UltimoSeguimiento);

/// <summary>Observación fechada del coordinador (se identifica por id).</summary>
public record Seguimiento(long IdSeguimiento, string CedulaEstudiante, DateOnly Fecha, string Observacion);

/// <summary>Reporte semestral enviado al guía.</summary>
public record ReporteMonografia(string CedulaEstudiante, int Anio, string Semestre, string Observaciones, DateTime EnviadoEn);

/// <summary>Coordinador CU01: monografía con su seguimiento y reportes.</summary>
public record DetalleMonografia(Monografia Monografia, List<Seguimiento> Seguimientos, List<ReporteMonografia> Reportes);

/// <summary>Guía CU07: monografía de un estudiante de la sección con su seguimiento.</summary>
public record MonografiaConSeguimiento(Monografia Monografia, List<Seguimiento> Seguimientos);

/// <summary>Guía CU06: reporte del semestre de un estudiante de la sección; Observaciones null = sin reporte.</summary>
public record ReporteMonografiaSeccion(
    string CedulaEstudiante,
    string NombreEstudiante,
    string CodigoAsignatura,
    string Asignatura,
    string NombreCoordinador,
    string Estado,
    string? Observaciones,
    DateTime? EnviadoEn);
