using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Evaluaciones.Models;

/// <summary>Asignación del profesor autenticado (año, nivel, número, código) y semestre.</summary>
public class ConsultaNotasAsignacion
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }

    [Required, MaxLength(10)]
    public string CodigoAsignatura { get; set; } = string.Empty;

    [Required, RegularExpression(Semestres.Patron, ErrorMessage = Semestres.Mensaje)]
    public string Semestre { get; set; } = string.Empty;
}

/// <summary>Nota de un estudiante. La escala según el tipo de asignatura la valida la DB (EV001): SUPERIOR y MEDIO
/// bandas 1 a 7, TRONCAL letras A a E, MEP enteros 0 a 100 (RN-73).</summary>
public class NotaRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaEstudiante { get; set; } = string.Empty;

    [Required, MaxLength(3)]
    public string Nota { get; set; } = string.Empty;

    /// <summary>Profesor Regular CU09: observaciones del profesor (salen en el reporte de bandas).</summary>
    [StringLength(500, MinimumLength = 3, ErrorMessage = "Las observaciones deben tener entre 3 y 500 caracteres.")]
    public string? Observaciones { get; set; }
}

/// <summary>Profesor Regular CU06 / CU07 / CU09: registra o corrige las notas de los estudiantes indicados (los demás no
/// cambian). EV002/EV003 fuera de plazo; EV004 estudiante que no se califica; EV005 repetido.</summary>
public class RegistrarNotasRequest : ConsultaNotasAsignacion
{
    [Required, MinLength(1, ErrorMessage = "Indica al menos una nota."), MaxLength(100, ErrorMessage = "No se pueden enviar más de 100 notas.")]
    public List<NotaRequest> Notas { get; set; } = [];
}

/// <summary>Guía CU03 / CU04: notas de una sección en un semestre.</summary>
public class ConsultaNotasSeccion
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }

    [Required, RegularExpression(Semestres.Patron, ErrorMessage = Semestres.Mensaje)]
    public string Semestre { get; set; } = string.Empty;
}

/// <summary>Prórroga de notas (RN-74): fecha límite posterior al fin del semestre y no pasada (EV007).</summary>
public class OtorgarProrrogaRequest
{
    [Required]
    public DateOnly? FechaLimite { get; set; }
}

/// <summary>Filtros opcionales del listado de prórrogas.</summary>
public class ConsultaProrrogas
{
    public int? Anio { get; set; }

    [RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string? CedulaProfesor { get; set; }
}

/// <summary>Nota de un estudiante en una asignación. Nota null = sin nota; NotaMinima y Aprobada null en TRONCAL.</summary>
public record NotaEstudiante(
    string CedulaEstudiante,
    string NombreEstudiante,
    string EstadoMatricula,
    string? Nota,
    string? NotaMinima,
    bool? Aprobada,
    string? Observaciones);

/// <summary>Estado de las notas de una asignación en un semestre. FechaCierre incluye la prórroga; EnviadoEn null = sin enviar.</summary>
public record EstadoNotas(
    int Anio,
    string Seccion,
    string CodigoAsignatura,
    string Asignatura,
    string TipoAsignatura,
    string Semestre,
    DateOnly FechaCierre,
    DateTime? EnviadoEn,
    int Estudiantes,
    int SinNota);

/// <summary>Profesor Regular CU08: estado y notas de la asignación.</summary>
public record NotasAsignacion(EstadoNotas Estado, List<NotaEstudiante> Notas);

/// <summary>Guía CU03: nota de un estudiante en una asignación de la sección; Nota solo si el profesor ya la envió.</summary>
public record NotaSeccion(
    string CedulaEstudiante,
    string NombreEstudiante,
    string EstadoMatricula,
    string CodigoAsignatura,
    string Asignatura,
    string TipoAsignatura,
    string NombreProfesor,
    bool Enviada,
    string? Nota,
    string? NotaMinima,
    bool? Aprobada,
    string? Observaciones);

/// <summary>Profesor Regular CU01: asignación con plazo de notas abierto. Aviso: NINGUNO, INFORMATIVO (30 días o menos)
/// o PRIORIDAD (15 días o menos) mientras falten notas o no se hayan enviado (RN-76).</summary>
public record AvisoNotas(
    int Anio,
    int Nivel,
    int Numero,
    string Seccion,
    string CodigoAsignatura,
    string Asignatura,
    string Semestre,
    DateOnly FechaCierre,
    int DiasParaCierre,
    int Estudiantes,
    int SinNota,
    bool Enviada,
    string Aviso);

/// <summary>Prórroga de un profesor en un semestre.</summary>
public record Prorroga(int Anio, string Semestre, string CedulaProfesor, string NombreProfesor, DateOnly FinSemestre, DateOnly FechaLimite);
