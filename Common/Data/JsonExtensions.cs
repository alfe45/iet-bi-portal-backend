using System.Text.Json;

namespace iet_bi_portal_backend.Common.Data;

public static class JsonExtensions
{
    /// <summary>Convierte el JSON que devuelve una función SQL (snapshot para auditoría) en un objeto
    /// serializable por ILogsService. null si no hay snapshot.</summary>
    public static JsonElement? ComoJson(this string? json) =>
        json is null ? null : JsonSerializer.Deserialize<JsonElement>(json);
}
