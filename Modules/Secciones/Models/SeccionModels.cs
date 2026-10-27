using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Secciones.Models;

/// <summary>CU13: sección de un nivel (11 u 12) en el periodo de un año. Nivel y número los valida la DB (SE002).</summary>
public class RegistrarSeccionRequest
{
    [Required]
    public int? Anio { get; set; }

    [Required]
    public int? Nivel { get; set; }

    [Required]
    public int? Numero { get; set; }
}

/// <summary>CU16: profesor guía de la sección, por cédula.</summary>
public class AsignarGuiaRequest
{
    [Required, RegularExpression(PatronesValidacion.Cedula, ErrorMessage = PatronesValidacion.MensajeCedula)]
    public string CedulaProfesor { get; set; } = string.Empty;
}

/// <summary>CU14: listado paginado con filtros opcionales por año y nivel.</summary>
public class ConsultaSecciones : ConsultaPaginada
{
    public int? Anio { get; set; }
    public int? Nivel { get; set; }
}

/// <summary>Sección tal como la devuelve academico.fn_*_seccion*. Se usa también como respuesta HTTP.
/// Nombre: "11-1". CedulaGuia/NombreGuia son null si no tiene guía. CantidadEstudiantes: matrículas no retiradas.</summary>
public record Seccion(
    int Anio,
    int Nivel,
    int Numero,
    string Nombre,
    string? CedulaGuia,
    string? NombreGuia,
    long CantidadEstudiantes);
