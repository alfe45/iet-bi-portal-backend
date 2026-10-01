using System.Text.Json;
using iet_bi_portal_backend.Modules.Logs.Data;

namespace iet_bi_portal_backend.Modules.Logs.Services;

/// <summary>Servicio de auditoría. Cualquier módulo lo inyecta sin depender de su implementación.</summary>
public interface ILogsService
{
    /// <summary>Registra una entrada de auditoría. idActor es null para acciones del sistema.
    /// datosAnteriores/datosNuevos son objetos cualesquiera (se serializan aquí); null si no aplica.
    /// Nunca pasar contraseñas ni hashes (RP-39).</summary>
    Task RegistrarAsync(
        Guid? idActor,
        string accion,
        string? tabla = null,
        string? idRegistro = null,
        object? datosAnteriores = null,
        object? datosNuevos = null,
        string? ip = null,
        string? userAgent = null);
}

public class LogsService(LogsRepository repo) : ILogsService
{
    public Task RegistrarAsync(
        Guid? idActor,
        string accion,
        string? tabla = null,
        string? idRegistro = null,
        object? datosAnteriores = null,
        object? datosNuevos = null,
        string? ip = null,
        string? userAgent = null) =>
        repo.RegistrarAsync(idActor, accion, tabla, idRegistro,
            Serializar(datosAnteriores), Serializar(datosNuevos), ip, userAgent);

    private static string? Serializar(object? datos) => datos is null ? null : JsonSerializer.Serialize(datos);
}
