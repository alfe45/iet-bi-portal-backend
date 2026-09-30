using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Matriculas.Models;

/// <summary>CU22: matricular un estudiante en una sección (año, nivel, número). FechaMatricula es opcional
/// (por defecto hoy, o el inicio del periodo si ya finalizó). Edad (ES003), duplicado (MA001) y fecha (MA002)
/// los valida la DB.</summary>
public class RegistrarMatriculaRequest
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }

    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaEstudiante { get; set; } = string.Empty;

    public DateOnly? FechaMatricula { get; set; }
}

/// <summary>CU22 - Subir la sección (RN-64): matricula en la 11-{Numero} de {Anio} a todos los estudiantes sin retiro de la
/// 10-{Numero} del año anterior; crea la 11-N si no existe. FechaMatricula opcional (como en la matrícula individual).</summary>
public class SubirSeccionRequest
{
    [Required]
    public int? Anio { get; set; }

    [Required, Range(1, 99, ErrorMessage = "El número de sección debe estar entre 1 y 99.")]
    public int? Numero { get; set; }

    public DateOnly? FechaMatricula { get; set; }
}

/// <summary>Resultado de subir la sección: si se creó la 11-N, cédulas matriculadas y omitidas (ya tenían matrícula en el año).</summary>
public record SeccionSubida(bool SeccionCreada, string[] Matriculados, string[] Omitidos);

/// <summary>CU23: trasladar la matrícula a otra sección del mismo año.</summary>
public class CambiarSeccionRequest
{
    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }
}

/// <summary>CU23: registrar o corregir el retiro del estudiante (MA003 fecha inválida).</summary>
public class RegistrarRetiroRequest
{
    [Required]
    public DateOnly? FechaRetiro { get; set; }

    [MaxLength(255)]
    public string? Motivo { get; set; }
}

/// <summary>CU24: listado/historial paginado; todos los filtros son opcionales. Busqueda: nombre o cédula.</summary>
public class ConsultaMatriculas : ConsultaConBusqueda
{
    public int? Anio { get; set; }

    [Range(10, 11, ErrorMessage = "El nivel debe ser 10 u 11.")]
    public int? Nivel { get; set; }

    public int? Numero { get; set; }

    [MaxLength(20)]
    public string? CedulaEstudiante { get; set; }

    [RegularExpression(EstadosMatricula.Patron, ErrorMessage = EstadosMatricula.Mensaje)]
    public string? Estado { get; set; }
}

/// <summary>Valores del enum academico.estado_matricula (deben coincidir con la DB).</summary>
public static class EstadosMatricula
{
    public const string Patron = "(?i)^(PROGRAMADA|ACTIVA|FINALIZADA|RETIRADA)$";   // sin distinguir mayúsculas
    public const string Mensaje = "El estado debe ser PROGRAMADA, ACTIVA, FINALIZADA o RETIRADA.";
}

/// <summary>Matrícula tal como la devuelve academico.fn_*_matricula*. Se usa también como respuesta HTTP.
/// Estado derivado: RETIRADA si tiene retiro; si no PROGRAMADA / ACTIVA / FINALIZADA según el periodo.</summary>
public record Matricula(
    int Anio,
    int Nivel,
    int Numero,
    string Seccion,
    string CedulaEstudiante,
    string NombreEstudiante,
    DateOnly FechaMatricula,
    string Estado,
    DateOnly? FechaRetiro,
    string? MotivoRetiro);

/// <summary>Profesor Regular CU05 (RN-65): ficha de un estudiante de la sección con su matrícula en ella.
/// Tal como la devuelve academico.fn_profesor_obtener_estudiante_seccion; no expone el id interno (RP-07).</summary>
public record FichaEstudiante(
    string Cedula,
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento,
    int Anio,
    string Seccion,
    DateOnly FechaMatricula,
    string Estado,
    DateOnly? FechaRetiro,
    string? MotivoRetiro);
