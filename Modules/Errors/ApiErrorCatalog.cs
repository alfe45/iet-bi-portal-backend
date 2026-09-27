using System.Text.Json;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary>
/// Diccionario central: para cada código (propio, lanzado por auth.fn_lanzar_excepcion,
/// o nativo de Postgres) define el status HTTP y el mensaje seguro para el cliente.
/// Se carga una sola vez desde error_codes.json. Un código que no está en el diccionario
/// nunca se expone tal cual — GlobalExceptionHandler responde 500 genérico.
///
/// Para agregar errores de otro módulo: se agregan las claves nuevas directamente en
/// error_codes.json. No hace falta tocar esta clase.
/// </summary>
public static class ApiErrorCatalog
{
    public sealed record ApiErrorInfo(int Status, string Mensaje);

    private sealed record ErrorJson(int Status, string Mensaje);

    private static readonly string FilePath =
        Path.Combine(AppContext.BaseDirectory, "Modules", "Errors", "error_codes.json");

    public static readonly IReadOnlyDictionary<string, ApiErrorInfo> Errors = Load();

    private static IReadOnlyDictionary<string, ApiErrorInfo> Load()
    {
        if (!File.Exists(FilePath))
            throw new InvalidOperationException(
                $"No se encontró el catálogo de errores en '{FilePath}'. " +
                "Verifica que error_codes.json esté configurado para copiarse al output.");

        var json = File.ReadAllText(FilePath);
        var raw = JsonSerializer.Deserialize<Dictionary<string, ErrorJson>>(
            json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        if (raw is null || raw.Count == 0)
            throw new InvalidOperationException("error_codes.json está vacío o mal formado.");

        return raw.ToDictionary(kv => kv.Key, kv => new ApiErrorInfo(kv.Value.Status, kv.Value.Mensaje));
    }
}