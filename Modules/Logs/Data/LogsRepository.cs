using Npgsql;
using iet_bi_portal_backend.Common.Data;

namespace iet_bi_portal_backend.Modules.Logs.Data;

/// <summary>Acceso a api.logs. No conoce reglas de negocio de ningún otro módulo: solo inserta
/// una entrada de auditoría vía api.fn_registrar_log.</summary>
public class LogsRepository(NpgsqlDataSource db)
{
    /// <summary>idActor es null para acciones del sistema/background. Los JSON ya vienen serializados (o null).</summary>
    public Task<Guid> RegistrarAsync(
        Guid? idActor,
        string accion,
        string? tablaAfectada,
        string? idRegistroAfectado,
        string? datosAnterioresJson,
        string? datosNuevosJson,
        string? ip,
        string? userAgent) =>
        db.EscalarAsync<Guid>(
            "SELECT api.fn_registrar_log($1::uuid, $2::text, $3::text, $4::text, $5::jsonb, $6::jsonb, $7::text, $8::text)",
            idActor, accion, tablaAfectada, idRegistroAfectado, datosAnterioresJson, datosNuevosJson, ip, userAgent);
}
