using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Periodos.Data;
using iet_bi_portal_backend.Modules.Periodos.Models;

namespace iet_bi_portal_backend.Modules.Periodos.Services;

public class PeriodosService(PeriodosRepository repo, ILogsService logs)
{
    private const string Tabla = "academico.periodos_academicos";

    /// <summary>CU14: registra un periodo con sus dos semestres. Devuelve el año.</summary>
    public async Task<int> RegistrarAsync(Guid actorId, RegistrarPeriodoRequest request)
    {
        var anio = await repo.RegistrarAsync(actorId, request);

        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarPeriodo, Tabla, anio.ToString(), datosNuevos: request);
        return anio;
    }

    /// <summary>CU15: listado paginado (más reciente primero).</summary>
    public Task<ResultadoPaginado<PeriodoAcademico>> ListarAsync(Guid actorId, int pagina, int tamanoPagina) =>
        repo.ListarAsync(actorId, pagina, tamanoPagina);

    /// <summary>CU15: detalle por año, o null si no existe.</summary>
    public Task<PeriodoAcademico?> ObtenerAsync(Guid actorId, int anio) => repo.ObtenerAsync(actorId, anio);

    /// <summary>Periodo en curso (año y semestre actual), o null si hoy no cae en ningún periodo.</summary>
    public Task<PeriodoAcademico?> ObtenerActualAsync() => repo.ObtenerActualAsync();

    /// <summary>CU16: modifica las fechas. Registra snapshot previo y datos nuevos solo si hubo cambios.</summary>
    public async Task ActualizarAsync(Guid actorId, int anio, ActualizarPeriodoRequest request)
    {
        var (estado, anteriores) = await repo.ActualizarAsync(actorId, anio, request);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarPeriodo, Tabla, anio.ToString(),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU17: elimina un periodo sin secciones.</summary>
    public async Task EliminarAsync(Guid actorId, int anio)
    {
        var anteriores = await repo.EliminarAsync(actorId, anio);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarPeriodo, Tabla, anio.ToString(),
            datosAnteriores: anteriores.ComoJson());
    }
}
