using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Asignaciones.Data;
using iet_bi_portal_backend.Modules.Asignaciones.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Asignaciones.Services;

public class AsignacionesService(AsignacionesRepository repo, ILogsService logs)
{
    private const string Tabla = "academico.asignaciones_docentes";

    /// <summary>Identificador de auditoría: "2026/10-1/MAT/1-1111-1111".</summary>
    private static string IdRegistro(int anio, int nivel, int numero, string codigo, string cedula) =>
        $"{anio}/{nivel}-{numero}/{codigo.Trim().ToUpperInvariant()}/{cedula.Trim()}";

    /// <summary>CU30: asigna a un profesor una asignatura en una sección.</summary>
    public async Task RegistrarAsync(Guid actorId, RegistrarAsignacionRequest request)
    {
        await repo.RegistrarAsync(actorId, request);

        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarAsignacion, Tabla,
            IdRegistro(request.Anio!.Value, request.Nivel!.Value, request.Numero!.Value, request.CodigoAsignatura, request.CedulaProfesor),
            datosNuevos: request);
    }

    /// <summary>CU31: listado paginado con filtros opcionales.</summary>
    public Task<ResultadoPaginado<Asignacion>> ListarAsync(Guid actorId, ConsultaAsignaciones consulta) => repo.ListarAsync(actorId, consulta);

    /// <summary>CU32: reemplaza al profesor de la asignación. Registra log solo si hubo cambios.</summary>
    public async Task CambiarProfesorAsync(
        Guid actorId, int anio, int nivel, int numero, string codigo, string cedula, CambiarProfesorRequest request)
    {
        var (estado, anteriores) = await repo.CambiarProfesorAsync(
            actorId, anio, nivel, numero, codigo, cedula, request.CedulaProfesorNuevo);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.CambiarProfesorAsignacion, Tabla,
                IdRegistro(anio, nivel, numero, codigo, request.CedulaProfesorNuevo),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU33: elimina la asignación.</summary>
    public async Task EliminarAsync(Guid actorId, int anio, int nivel, int numero, string codigo, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, anio, nivel, numero, codigo, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarAsignacion, Tabla,
            IdRegistro(anio, nivel, numero, codigo, cedula), datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Profesor Regular CU03: mis asignaciones de un año (null = periodo en curso).</summary>
    public Task<List<Asignacion>> ListarMisAsignacionesAsync(Guid idUsuario, int? anio) =>
        repo.ListarMisAsignacionesAsync(idUsuario, anio);
}
