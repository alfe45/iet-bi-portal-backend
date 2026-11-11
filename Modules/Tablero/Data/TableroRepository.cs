using System.Text.Json;
using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Modules.Tablero.Models;

namespace iet_bi_portal_backend.Modules.Tablero.Data;

/// <summary>Tablero del Administrador: academico.fn_admin_tablero devuelve un JSON con todos los bloques (RP-62).</summary>
public class TableroRepository(NpgsqlDataSource db)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <summary>Errores: AU009 (no es administrador activo), NF004 (el año no existe).</summary>
    public async Task<TableroAdmin> ObtenerAsync(Guid actorId, int? anio)
    {
        var json = await db.EscalarAsync<string>("SELECT academico.fn_admin_tablero($1, $2::integer)::text", actorId, anio);
        return JsonSerializer.Deserialize<TableroAdmin>(json, Json)
            ?? throw new InvalidOperationException("Respuesta vacía de academico.fn_admin_tablero.");
    }
}
