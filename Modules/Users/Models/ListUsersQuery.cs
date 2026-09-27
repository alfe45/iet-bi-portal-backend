using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Parámetros de paginación para el listado de usuarios (CU03). Sin filtros:
/// los aplica el frontend sobre el resultado, o se agregan más adelante si hace falta.</summary>
public class ListUsersQuery
{
    [Range(1, int.MaxValue, ErrorMessage = "La página debe ser mayor o igual a 1.")]
    public int Page { get; set; } = 1;

    [Range(1, 100, ErrorMessage = "El tamaño de página debe estar entre 1 y 100.")]
    public int PageSize { get; set; } = 20;
}