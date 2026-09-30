using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Ausentismo.Data;
using iet_bi_portal_backend.Modules.Ausentismo.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Ausentismo.Services;

public class AusentismoService(AusentismoRepository repo, ILogsService logs)
{
    private const string TablaLecciones = "academico.lecciones";
    private const string TablaAusencias = "academico.ausencias";

    /// <summary>CU10: registra la lección con sus ausentes. Devuelve el id de la lección.</summary>
    public async Task<long> RegistrarLeccionAsync(Guid actorId, RegistrarLeccionRequest request)
    {
        var idLeccion = await repo.RegistrarLeccionAsync(actorId, request);
        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarLeccion, TablaLecciones, idLeccion.ToString(), datosNuevos: request);
        return idLeccion;
    }

    /// <summary>CU11: corrige la lección y reemplaza los ausentes. Registra log solo si hubo cambios.</summary>
    public async Task ModificarLeccionAsync(Guid actorId, long idLeccion, ModificarLeccionRequest request)
    {
        var (estado, anteriores) = await repo.ModificarLeccionAsync(actorId, idLeccion, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarLeccion, TablaLecciones, idLeccion.ToString(),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU11: elimina la lección y sus ausencias.</summary>
    public async Task EliminarLeccionAsync(Guid actorId, long idLeccion)
    {
        var anteriores = await repo.EliminarLeccionAsync(actorId, idLeccion);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarLeccion, TablaLecciones, idLeccion.ToString(),
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>CU11: justifica una ausencia (RN-69). Registra log solo si hubo cambios.</summary>
    public async Task JustificarAusenciaAsync(Guid actorId, long idLeccion, string cedula, JustificarAusenciaRequest request)
    {
        var (estado, anteriores) = await repo.JustificarAusenciaAsync(actorId, idLeccion, cedula, request.Justificacion);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.JustificarAusencia, TablaAusencias, $"{idLeccion}/{cedula.Trim()}",
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU11: anula la justificación (la ausencia vuelve a ser injustificada). Registra log solo si tenía una.</summary>
    public async Task AnularJustificacionAsync(Guid actorId, long idLeccion, string cedula)
    {
        var (estado, anteriores) = await repo.JustificarAusenciaAsync(actorId, idLeccion, cedula, null);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.AnularJustificacionAusencia, TablaAusencias, $"{idLeccion}/{cedula.Trim()}",
                datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>CU12: lecciones de una asignación del profesor.</summary>
    public Task<ResultadoPaginado<Leccion>> ListarLeccionesAsync(Guid idUsuario, ConsultaLecciones consulta) =>
        repo.ListarLeccionesAsync(idUsuario, consulta);

    /// <summary>CU12: detalle de una lección con sus ausentes.</summary>
    public Task<LeccionConAusentes> ObtenerLeccionAsync(Guid idUsuario, long idLeccion) => repo.ObtenerLeccionAsync(idUsuario, idLeccion);

    /// <summary>CU12: resumen de ausentismo por estudiante de una asignación del profesor (RN-70).</summary>
    public Task<List<ResumenAusentismo>> ResumenProfesorAsync(Guid idUsuario, ConsultaAusentismo consulta) =>
        repo.ResumenProfesorAsync(idUsuario, consulta);

    /// <summary>Guía CU05: resumen por estudiante y asignatura de la sección guía (RN-71).</summary>
    public Task<List<ResumenAusentismo>> ResumenGuiaAsync(Guid idUsuario, ConsultaAusentismoGuia consulta) =>
        repo.ResumenGuiaAsync(idUsuario, consulta);
}
