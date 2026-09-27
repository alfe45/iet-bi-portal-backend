using Microsoft.AspNetCore.Diagnostics;
using Npgsql;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary>
/// Único punto de manejo de excepciones no capturadas. Respuesta siempre con
/// forma { codigo, mensaje }. Solo se exponen al cliente los códigos que están
/// catalogados en ApiErrorCatalog, con un mensaje fijo y seguro; cualquier otro
/// error (de Postgres o no) responde 500 genérico y nunca filtra texto interno
/// del motor (message/detail de Postgres pueden contener datos del usuario).
/// </summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception ex, CancellationToken ct)
    {
        var (status, codigo, mensaje) = ex switch
        {
            PostgresException pg when ApiErrorCatalog.Errors.TryGetValue(pg.SqlState ?? "", out var info)
                => (info.Status, pg.SqlState!, info.Mensaje),

            PostgresException
                => (StatusCodes.Status500InternalServerError, "DB_ERROR", "Ocurrió un error al procesar la solicitud."),

            UnauthorizedAccessException
                => (StatusCodes.Status401Unauthorized, "UNAUTHORIZED", "No autorizado."),

            _ => (StatusCodes.Status500InternalServerError, "INTERNAL_ERROR", "Ocurrió un error inesperado.")
        };

        if (ex is PostgresException pg2 && !ApiErrorCatalog.Errors.ContainsKey(pg2.SqlState ?? ""))
            logger.LogError(ex, "PostgresException no catalogada [{SqlState}] en {Metodo} {Ruta}: {Mensaje}",
                pg2.SqlState, http.Request.Method, http.Request.Path, pg2.MessageText);
        else if (status >= 500)
            logger.LogError(ex, "Error no controlado en {Metodo} {Ruta}", http.Request.Method, http.Request.Path);
        else
            logger.LogWarning("[{Codigo}] {Mensaje} en {Metodo} {Ruta}", codigo, mensaje, http.Request.Method, http.Request.Path);

        http.Response.StatusCode = status;
        await http.Response.WriteAsJsonAsync(new { codigo, mensaje }, ct);
        return true;
    }
}