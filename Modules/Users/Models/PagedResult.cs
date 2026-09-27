namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Resultado paginado genérico. Se pensó para reutilizarse en otros listados
/// (ej. Estudiantes) que necesiten la misma forma de paginación.</summary>
public record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, long TotalCount);