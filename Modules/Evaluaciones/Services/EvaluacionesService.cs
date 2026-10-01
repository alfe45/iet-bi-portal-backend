using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Evaluaciones.Data;
using iet_bi_portal_backend.Modules.Evaluaciones.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Evaluaciones.Services;

public class EvaluacionesService(EvaluacionesRepository repo, ILogsService logs)
{
    private const string TablaEvaluaciones = "academico.evaluaciones";
    private const string TablaEnvios = "academico.envios_notas";
    private const string TablaProrrogas = "academico.prorrogas";

    /// <summary>CU06 / CU07 / CU09: registra o corrige notas y observaciones. Registra log solo si hubo cambios.</summary>
    public async Task RegistrarNotasAsync(Guid actorId, RegistrarNotasRequest request)
    {
        var (estado, anteriores) = await repo.RegistrarNotasAsync(actorId, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.RegistrarNotas, TablaEvaluaciones, IdAsignacion(request),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request.Notas);
    }

    /// <summary>CU07: elimina la nota de un estudiante y anula el envío de la asignación (RN-75).</summary>
    public async Task EliminarNotaAsync(Guid actorId, ConsultaNotasAsignacion asignacion, string cedula)
    {
        var anteriores = await repo.EliminarNotaAsync(actorId, asignacion, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarNota, TablaEvaluaciones, $"{IdAsignacion(asignacion)}/{cedula.Trim()}",
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>CU08: estado y notas de mi asignación en el semestre.</summary>
    public Task<NotasAsignacion> ListarNotasAsync(Guid idUsuario, ConsultaNotasAsignacion consulta) =>
        repo.ListarNotasAsync(idUsuario, consulta);

    /// <summary>CU14: envía las notas al guía (RN-75). Registra log solo la primera vez.</summary>
    public async Task EnviarNotasAsync(Guid actorId, ConsultaNotasAsignacion request)
    {
        if (await repo.EnviarNotasAsync(actorId, request) == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.EnviarNotas, TablaEnvios, IdAsignacion(request));
    }

    /// <summary>CU01: avisos de la pantalla principal (RN-76).</summary>
    public Task<List<AvisoNotas>> AvisosAsync(Guid idUsuario) => repo.AvisosAsync(idUsuario);

    /// <summary>Guía CU03 / CU04: notas enviadas de una sección (RN-77).</summary>
    public Task<List<NotaSeccion>> NotasSeccionAsync(ConsultaNotasSeccion consulta) => repo.NotasSeccionAsync(consulta);

    /// <summary>Otorga o cambia la prórroga (RN-74). Registra log solo si hubo cambios.</summary>
    public async Task OtorgarProrrogaAsync(Guid actorId, int anio, string semestre, string cedula, OtorgarProrrogaRequest request)
    {
        var (estado, anteriores) = await repo.OtorgarProrrogaAsync(actorId, anio, semestre, cedula, request.FechaLimite);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.OtorgarProrroga, TablaProrrogas, IdProrroga(anio, semestre, cedula),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    public async Task QuitarProrrogaAsync(Guid actorId, int anio, string semestre, string cedula)
    {
        var anteriores = await repo.QuitarProrrogaAsync(actorId, anio, semestre, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.QuitarProrroga, TablaProrrogas, IdProrroga(anio, semestre, cedula),
            datosAnteriores: anteriores.ComoJson());
    }

    public Task<List<Prorroga>> ListarProrrogasAsync(Guid actorId, ConsultaProrrogas consulta) => repo.ListarProrrogasAsync(actorId, consulta);

    private static string IdAsignacion(ConsultaNotasAsignacion r) =>
        $"{r.Anio}/{r.Nivel}-{r.Numero}/{r.CodigoAsignatura.Trim().ToUpperInvariant()}/{Semestres.Normalizar(r.Semestre)}";

    private static string IdProrroga(int anio, string semestre, string cedula) =>
        $"{anio}/{Semestres.Normalizar(semestre)}/{cedula.Trim()}";
}
