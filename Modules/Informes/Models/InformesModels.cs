using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Informes.Models;

/// <summary>Guía CU08 / CU09: su sección guía en un semestre.</summary>
public class ConsultaReporteBandas
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

/// <summary>Fila del reporte por asignación. NotaMinima: banda o nota mínima (null en TRONCAL); Nota: la registrada hasta el
/// momento (null si no hay); Confirmada: si el profesor ya confirmó las notas de la asignación (RN-75). Ausentismo del
/// semestre: tardías, ausencias injustificadas y justificadas.</summary>
public record BandaAsignatura(
    string CodigoAsignatura,
    string Asignatura,
    string TipoAsignatura,
    string NombreProfesor,
    string? NotaMinima,
    string? Nota,
    bool? Aprobada,
    int Tardias,
    int Injustificadas,
    int Justificadas,
    string? Observaciones,
    bool Confirmada);

/// <summary>Sección de monografía: área (materia), coordinador y observaciones del reporte del semestre (null = sin informe).</summary>
public record MonografiaReporte(string CodigoAsignatura, string Area, string NombreCoordinador, string Estado, string? Observaciones, DateTime? EnviadoEn);

/// <summary>Reporte de bandas de un estudiante en un semestre (RN-85). El front agrupa las asignaturas por tipo (BI:
/// SUPERIOR y MEDIO; TRONCAL; MEP) y arma el PDF con las líneas de firma (guía, encargado y fecha). NombreGuia null si la
/// sección no tiene guía. Monografia null si el estudiante no tiene.</summary>
public record ReporteBandas(
    int Anio,
    string Semestre,
    int Nivel,
    string Seccion,
    string CedulaEstudiante,
    string NombreEstudiante,
    string? NombreGuia,
    List<BandaAsignatura> Asignaturas,
    MonografiaReporte? Monografia);
