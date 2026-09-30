using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Common.Models;

/// <summary>Parámetros de paginación reutilizables para listados sin filtros.</summary>
public class ConsultaPaginada
{
    [Range(1, int.MaxValue, ErrorMessage = "La página debe ser mayor o igual a 1.")]
    public int Pagina { get; set; } = 1;

    [Range(1, 100, ErrorMessage = "El tamaño de página debe estar entre 1 y 100.")]
    public int TamanoPagina { get; set; } = 20;
}

/// <summary>Listado paginado con búsqueda de texto opcional (sin distinguir mayúsculas ni acentos).</summary>
public class ConsultaConBusqueda : ConsultaPaginada
{
    [MaxLength(100)]
    public string? Busqueda { get; set; }
}

/// <summary>Resultado paginado genérico; también es la respuesta HTTP de los listados.</summary>
public record ResultadoPaginado<T>(IReadOnlyList<T> Elementos, int Pagina, int TamanoPagina, long Total);
