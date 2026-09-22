using System.Text.Json;
using Microsoft.AspNetCore.Diagnostics;
using Npgsql;

public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception ex, CancellationToken ct)
    {
        int status = 400;
        string mensaje = "Ocurrió un error inesperado.";
        string? codigo = null;
        object? datos = null;
        string? sugerencia = null;

        switch (ex)
        {
            case PostgresException pg:
                status = 422;
                mensaje = pg.MessageText;
                codigo = pg.SqlState;
                datos = ParsearJson(pg.Detail);
                sugerencia = string.IsNullOrEmpty(pg.Hint) ? null : pg.Hint;
                logger.LogWarning("[{Codigo}] {Mensaje}", codigo, mensaje);
                break;

            case UnauthorizedAccessException:
                status = 401;
                mensaje = "No autorizado.";
                codigo = "UNAUTHORIZED";
                datos = null;
                sugerencia = null;
                logger.LogWarning("[{Codigo}] {Mensaje}", codigo, mensaje);
                break;

            default:
                status = 500;
                mensaje = "Ocurrió un error inesperado.";
                datos = ex.Message;

                logger.LogError(ex, "Error no controlado en {Metodo} {Ruta}",
                    http.Request.Method, http.Request.Path);
                break;
        }

        http.Response.StatusCode = status;
        await http.Response.WriteAsJsonAsync(new { mensaje, codigo, datos, sugerencia }, ct);
        return true;
    }

    private static object? ParsearJson(string? detail)
    {
        if (string.IsNullOrWhiteSpace(detail)) return null;
        try { return JsonDocument.Parse(detail).RootElement.Clone(); }
        catch (JsonException) { return detail; }
    }
}