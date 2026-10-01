using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Modules.Cas.Models;

/// <summary>Fila del informe CAS: proyecto, serie de experiencias o experiencia (en el orden del formato). Fecha opcional,
/// no futura y dentro del periodo (CA001). ResultadosAprendizaje: cuáles de los 7 resultados de aprendizaje cumple.</summary>
public class ExperienciaCasRequest : IValidatableObject
{
    [Required, StringLength(255, MinimumLength = 3, ErrorMessage = "La descripción debe tener entre 3 y 255 caracteres.")]
    public string Descripcion { get; set; } = string.Empty;

    public DateOnly? Fecha { get; set; }

    public bool Creatividad { get; set; }
    public bool Actividad { get; set; }
    public bool Servicio { get; set; }

    [MaxLength(7, ErrorMessage = "Hay 7 resultados de aprendizaje como máximo.")]
    public List<int> ResultadosAprendizaje { get; set; } = [];

    public bool Carpeta { get; set; }
    public bool Reflexion { get; set; }
    public bool Pruebas { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (ResultadosAprendizaje.Any(r => r is < 1 or > 7))
            yield return new ValidationResult("Los resultados de aprendizaje van del 1 al 7.", [nameof(ResultadosAprendizaje)]);
    }
}

/// <summary>Profesor CAS CU01 / CU02: informe del estudiante en el semestre (RN-83). Reemplaza el informe anterior.
/// Perfil y entrevistas: lo que el estudiante lleva cumplido hasta ese semestre.</summary>
public class GuardarInformeCasRequest
{
    public bool Perfil { get; set; }
    public bool Entrevista1 { get; set; }
    public bool Entrevista2 { get; set; }
    public bool EntrevistaFinal { get; set; }

    [MaxLength(2000)]
    public string? Observaciones { get; set; }

    [MaxLength(30, ErrorMessage = "El informe admite como máximo 30 experiencias.")]
    public List<ExperienciaCasRequest> Experiencias { get; set; } = [];
}

/// <summary>Profesor CAS CU03: mi sección CAS en un semestre.</summary>
public class ConsultaProgresoSeccion
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

/// <summary>Coordinador de CAS CU01: todas las secciones del año, o filtradas por nivel y número.</summary>
public class ConsultaProgresoGeneral
{
    [Required]
    public int? Anio { get; set; }

    public int? Nivel { get; set; }

    public int? Numero { get; set; }

    [Required, RegularExpression(Semestres.Patron, ErrorMessage = Semestres.Mensaje)]
    public string Semestre { get; set; } = string.Empty;
}

/// <summary>Fila del informe tal como se guardó.</summary>
public record ExperienciaCas(
    int Orden,
    string Descripcion,
    DateOnly? Fecha,
    bool Creatividad,
    bool Actividad,
    bool Servicio,
    List<int> ResultadosAprendizaje,
    bool Carpeta,
    bool Reflexion,
    bool Pruebas);

/// <summary>Informe CAS completo, con los datos para el formato del Instituto (el front arma el PDF). Nota: la nota CAS del
/// semestre (para el coordinador, solo si el profesor ya la envió).</summary>
public record InformeCas(
    int Anio,
    string Semestre,
    string Seccion,
    string CedulaEstudiante,
    string NombreEstudiante,
    string EmailEstudiante,
    string CedulaProfesor,
    string NombreProfesor,
    bool Perfil,
    bool Entrevista1,
    bool Entrevista2,
    bool EntrevistaFinal,
    string? Observaciones,
    string? Nota,
    bool NotaEnviada,
    DateTime ModificadoEn,
    List<ExperienciaCas> Experiencias);

/// <summary>Progreso CAS de un estudiante en el semestre (RN-84). Entrevistas: cuántas de las 3 lleva.</summary>
public record ProgresoCas(
    int Anio,
    string Seccion,
    string CedulaEstudiante,
    string NombreEstudiante,
    string NombreProfesor,
    string Semestre,
    bool TieneInforme,
    int Experiencias,
    bool Perfil,
    int Entrevistas,
    string? Nota,
    bool NotaEnviada);
