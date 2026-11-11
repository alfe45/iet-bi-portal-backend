using iet_bi_portal_backend.Modules.Tablero.Data;
using iet_bi_portal_backend.Modules.Tablero.Models;

namespace iet_bi_portal_backend.Modules.Tablero.Services;

/// <summary>Tablero del Administrador (RP-62). Solo lectura: no se audita.</summary>
public class TableroService(TableroRepository repo)
{
    public Task<TableroAdmin> ObtenerAsync(Guid actorId, int? anio) => repo.ObtenerAsync(actorId, anio);
}
