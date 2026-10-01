using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Asignaturas.Data;
using iet_bi_portal_backend.Modules.Asignaturas.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Asignaturas.Services;

public class AsignaturasService(AsignaturasRepository repo, ILogsService logs)
{
    private const string Tabla = "academico.asignaturas";

    /// <summary>CU26: registra una asignatura. Devuelve el código normalizado.</summary>
    public async Task<string> RegistrarAsync(Guid actorId, RegistrarAsignaturaRequest request)
    {
        var codigo = await repo.RegistrarAsync(actorId, request);

        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarAsignatura, Tabla, codigo, datosNuevos: request);
        return codigo;
    }

    /// <summary>CU27: listado paginado con filtros opcionales.</summary>
    public Task<ResultadoPaginado<Asignatura>> ListarAsync(Guid actorId, ConsultaAsignaturas consulta) => repo.ListarAsync(actorId, consulta);

    /// <summary>CU27: detalle por código, o null si no existe.</summary>
    public Task<Asignatura?> ObtenerAsync(Guid actorId, string codigo) => repo.ObtenerAsync(actorId, codigo);

    /// <summary>CU28: modifica una asignatura. Registra snapshot previo y datos nuevos solo si hubo cambios.</summary>
    public async Task ActualizarAsync(Guid actorId, string codigo, ActualizarAsignaturaRequest request)
    {
        var (estado, anteriores) = await repo.ActualizarAsync(actorId, codigo, request);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarAsignatura, Tabla, codigo.Trim().ToUpperInvariant(),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU29: elimina una asignatura.</summary>
    public async Task EliminarAsync(Guid actorId, string codigo)
    {
        var anteriores = await repo.EliminarAsync(actorId, codigo);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarAsignatura, Tabla, codigo.Trim().ToUpperInvariant(),
            datosAnteriores: anteriores.ComoJson());
    }
}
