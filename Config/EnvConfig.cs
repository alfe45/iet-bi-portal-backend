// Config/EnvConfig.cs
namespace iet_bi_portal_backend.Config;

/// <summary>Lee variables de entorno requeridas. </summary>
public static class EnvConfig
{
    public static string Required(IConfiguration config, string key) =>
        config[key] is { Length: > 0 } value
            ? value
            : throw new InvalidOperationException(
                $"Falta la variable de entorno '{key}'. Revisa tu archivo .env.");

    public static int RequiredInt(IConfiguration config, string key)
    {
        var raw = Required(config, key);
        return int.TryParse(raw, out var value)
            ? value
            : throw new InvalidOperationException(
                $"La variable de entorno '{key}' debe ser un número entero (valor actual: '{raw}').");
    }
}