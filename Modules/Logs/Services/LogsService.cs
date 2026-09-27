using System.Text.Json;
using iet_bi_portal_backend.Modules.Logs.Data;

namespace iet_bi_portal_backend.Modules.Logs.Services;

/// <summary>Servicio de auditoría. Cualquier módulo (Auth, Academico, lo que venga) lo
/// inyecta sin depender de cómo está implementado — solo de esta interfaz.</summary>
public interface ILogsService
{
    /// <summary> Registra una entrada de auditoría. actorUserId es null para acciones del
    /// sistema/background (jobs, background services). previousData/newData son objetos
    /// cualesquiera (se serializan a JSON acá adentro); pasar null si no aplica. </summary>
    Task RegisterLogAsync(
        Guid? actorUserId,
        string action,
        string? affectedTable = null,
        string? affectedRecordId = null,
        object? previousData = null,
        object? newData = null,
        string? ip = null,
        string? userAgent = null);
}

public class LogsService : ILogsService
{
    private readonly LogsRepository _repo;

    public LogsService(LogsRepository repo) => _repo = repo;

    public Task RegisterLogAsync(
        Guid? actorUserId,
        string action,
        string? affectedTable = null,
        string? affectedRecordId = null,
        object? previousData = null,
        object? newData = null,
        string? ip = null,
        string? userAgent = null) =>
        _repo.RegisterLogAsync(
            actorUserId,
            action,
            affectedTable,
            affectedRecordId,
            Serialize(previousData),
            Serialize(newData),
            ip,
            userAgent);

    private static string? Serialize(object? data) =>
        data is null ? null : JsonSerializer.Serialize(data);
}