using Npgsql;

namespace iet_bi_portal_backend.Modules.Logs.Data;

/// <summary>Acceso a la tabla api.logs. No conoce reglas de negocio de ningún otro módulo —
/// solo sabe insertar una entrada de auditoría vía api.fn_registrar_log.</summary>
public class LogsRepository
{
    private readonly NpgsqlDataSource _db;

    public LogsRepository(NpgsqlDataSource db) => _db = db;

    /// <summary> Inserta una entrada de auditoría. actorUserId es null para acciones del
    /// sistema/background. previousDataJson/newDataJson ya deben venir serializados (o null). </summary>
    public async Task<Guid> RegisterLogAsync(
        Guid? actorUserId,
        string action,
        string? affectedTable,
        string? affectedRecordId,
        string? previousDataJson,
        string? newDataJson,
        string? ip,
        string? userAgent)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT api.fn_registrar_log($1::uuid, $2::text, $3::text, $4::text, $5::jsonb, $6::jsonb, $7::text, $8::text)");

        cmd.Parameters.AddWithValue((object?)actorUserId ?? DBNull.Value);
        cmd.Parameters.AddWithValue(action);
        cmd.Parameters.AddWithValue((object?)affectedTable ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)affectedRecordId ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)previousDataJson ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)newDataJson ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)ip ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)userAgent ?? DBNull.Value);

        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id ? id : throw new InvalidOperationException("Respuesta inesperada de fn_registrar_log.");
    }
}