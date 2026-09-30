using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Asignaturas.Models;

/// <summary>CU31: datos editables de una asignatura. El código no se puede cambiar.
/// Unicidad del nombre (AS002) y "al menos un nivel" (AS003) los valida la DB.</summary>
public class ActualizarAsignaturaRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string Nombre { get; set; } = string.Empty;

    /// <summary>TRONCAL | SUPERIOR | MEDIO | MEP.</summary>
    [Required, RegularExpression(TiposAsignatura.Patron, ErrorMessage = TiposAsignatura.Mensaje)]
    public string Tipo { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? Descripcion { get; set; }

    [Required]
    public bool? ImparteNivel10 { get; set; }

    [Required]
    public bool? ImparteNivel11 { get; set; }
}

/// <summary>CU29: los mismos campos + el código (2 a 10 letras o dígitos; se guarda en mayúsculas).</summary>
public class RegistrarAsignaturaRequest : ActualizarAsignaturaRequest
{
    [Required, MaxLength(10)]
    public string Codigo { get; set; } = string.Empty;
}

/// <summary>CU30: listado paginado con filtros opcionales por tipo y nivel.</summary>
public class ConsultaAsignaturas : ConsultaPaginada
{
    [RegularExpression(TiposAsignatura.Patron, ErrorMessage = TiposAsignatura.Mensaje)]
    public string? Tipo { get; set; }

    [Range(10, 11, ErrorMessage = "El nivel debe ser 10 u 11.")]
    public int? Nivel { get; set; }
}

/// <summary>Valores del enum academico.tipo_asignatura (deben coincidir con la DB).</summary>
public static class TiposAsignatura
{
    public const string Patron = "(?i)^(TRONCAL|SUPERIOR|MEDIO|MEP)$";   // sin distinguir mayúsculas
    public const string Mensaje = "El tipo debe ser TRONCAL, SUPERIOR, MEDIO o MEP.";
}

/// <summary>Asignatura tal como la devuelve academico.fn_*_asignatura*. Se usa también como respuesta HTTP.</summary>
public record Asignatura(
    string Codigo,
    string Nombre,
    string Tipo,
    string? Descripcion,
    bool ImparteNivel10,
    bool ImparteNivel11);
