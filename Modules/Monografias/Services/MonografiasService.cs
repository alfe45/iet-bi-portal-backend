using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Monografias.Data;
using iet_bi_portal_backend.Modules.Monografias.Models;

namespace iet_bi_portal_backend.Modules.Monografias.Services;

public class MonografiasService(MonografiasRepository repo, ILogsService logs)
{
    private const string TablaMonografias = "academico.monografias";
    private const string TablaSeguimientos = "academico.seguimientos_monografia";
    private const string TablaReportes = "academico.reportes_monografia";

    /// <summary>Administrador CU34.</summary>
    public async Task RegistrarAsync(Guid actorId, RegistrarMonografiaRequest request)
    {
        await repo.RegistrarAsync(actorId, request);
        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarMonografia, TablaMonografias, request.CedulaEstudiante.Trim(), datosNuevos: request);
    }

    /// <summary>Administrador CU35.</summary>
    public Task<ResultadoPaginado<Monografia>> ListarAsync(Guid actorId, ConsultaMonografias consulta) => repo.ListarAsync(actorId, consulta);

    public Task<Monografia> ObtenerAsync(Guid actorId, string cedula) => repo.ObtenerAsync(actorId, cedula);

    /// <summary>Administrador CU36. Registra log solo si hubo cambios.</summary>
    public async Task ModificarAsync(Guid actorId, string cedula, ModificarMonografiaRequest request)
    {
        var (estado, anteriores) = await repo.ModificarAsync(actorId, cedula, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarMonografia, TablaMonografias, cedula.Trim(),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>Administrador CU37.</summary>
    public async Task EliminarAsync(Guid actorId, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarMonografia, TablaMonografias, cedula.Trim(),
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Coordinador CU01.</summary>
    public Task<List<Monografia>> ListarMiasAsync(Guid idUsuario, ConsultaMisMonografias consulta) => repo.ListarMiasAsync(idUsuario, consulta);

    public Task<DetalleMonografia> ObtenerMiaAsync(Guid idUsuario, string cedula) => repo.ObtenerMiaAsync(idUsuario, cedula);

    /// <summary>Coordinador CU02. Registra log solo si hubo cambios.</summary>
    public async Task CambiarEstadoAsync(Guid actorId, string cedula, CambiarEstadoMonografiaRequest request)
    {
        var (estado, anteriores) = await repo.CambiarEstadoAsync(actorId, cedula, request.Estado);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.CambiarEstadoMonografia, TablaMonografias, cedula.Trim(),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>Coordinador CU03. Devuelve el id del seguimiento.</summary>
    public async Task<long> RegistrarSeguimientoAsync(Guid actorId, string cedula, RegistrarSeguimientoRequest request)
    {
        var id = await repo.RegistrarSeguimientoAsync(actorId, cedula, request);
        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarSeguimientoMonografia, TablaSeguimientos, id.ToString(), datosNuevos: request);
        return id;
    }

    /// <summary>Coordinador CU04. Registra log solo si hubo cambios.</summary>
    public async Task ModificarSeguimientoAsync(Guid actorId, long idSeguimiento, ModificarSeguimientoRequest request)
    {
        var (estado, anteriores) = await repo.ModificarSeguimientoAsync(actorId, idSeguimiento, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarSeguimientoMonografia, TablaSeguimientos, idSeguimiento.ToString(),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>Coordinador CU04.</summary>
    public async Task EliminarSeguimientoAsync(Guid actorId, long idSeguimiento)
    {
        var anteriores = await repo.EliminarSeguimientoAsync(actorId, idSeguimiento);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarSeguimientoMonografia, TablaSeguimientos, idSeguimiento.ToString(),
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Coordinador CU05 (RN-81). Registra log solo si hubo cambios.</summary>
    public async Task EnviarReporteAsync(Guid actorId, string cedula, int anio, string semestre, ReporteMonografiaRequest request)
    {
        var (estado, anteriores) = await repo.EnviarReporteAsync(actorId, cedula, anio, semestre, request.Observaciones);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.EnviarReporteMonografia, TablaReportes,
                $"{cedula.Trim()}/{anio}/{Semestres.Normalizar(semestre)}", datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>Coordinador CU05: retira el reporte del semestre (corrección).</summary>
    public async Task EliminarReporteAsync(Guid actorId, string cedula, int anio, string semestre)
    {
        var anteriores = await repo.EliminarReporteAsync(actorId, cedula, anio, semestre);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarReporteMonografia, TablaReportes,
            $"{cedula.Trim()}/{anio}/{Semestres.Normalizar(semestre)}", datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Guía CU07.</summary>
    public Task<List<MonografiaConSeguimiento>> ListarSeccionGuiaAsync(Guid idUsuario, ConsultaSeccionGuia consulta) =>
        repo.ListarSeccionGuiaAsync(idUsuario, consulta);

    /// <summary>Guía CU06.</summary>
    public Task<List<ReporteMonografiaSeccion>> ReportesSeccionGuiaAsync(Guid idUsuario, ConsultaReportesGuia consulta) =>
        repo.ReportesSeccionGuiaAsync(idUsuario, consulta);
}
