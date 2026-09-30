using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Matriculas.Data;
using iet_bi_portal_backend.Modules.Matriculas.Models;

namespace iet_bi_portal_backend.Modules.Matriculas.Services;

public class MatriculasService(MatriculasRepository repo, ILogsService logs)
{
    private const string Tabla = "academico.matriculas";

    /// <summary>Identificador de auditoría: "2026/1-1111-1111".</summary>
    private static string IdRegistro(int anio, string cedula) => $"{anio}/{cedula.Trim()}";

    /// <summary>CU25: matricula al estudiante en la sección.</summary>
    public async Task RegistrarAsync(Guid actorId, RegistrarMatriculaRequest request)
    {
        await repo.RegistrarAsync(actorId, request);
        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarMatricula, Tabla,
            IdRegistro(request.Anio!.Value, request.CedulaEstudiante), datosNuevos: request);
    }

    /// <summary>CU27: listado / historial paginado con filtros opcionales.</summary>
    public Task<ResultadoPaginado<Matricula>> ListarAsync(ConsultaMatriculas consulta) => repo.ListarAsync(consulta);

    /// <summary>CU27: detalle, o null si no existe.</summary>
    public Task<Matricula?> ObtenerAsync(int anio, string cedula) => repo.ObtenerAsync(anio, cedula);

    /// <summary>CU26: traslado a otra sección del mismo año. Registra log solo si hubo cambios.</summary>
    public async Task CambiarSeccionAsync(Guid actorId, int anio, string cedula, CambiarSeccionRequest request)
    {
        var (estado, anteriores) = await repo.CambiarSeccionAsync(actorId, anio, cedula, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.CambiarSeccionMatricula, Tabla, IdRegistro(anio, cedula),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU26: registra o corrige el retiro. Registra log solo si hubo cambios.</summary>
    public async Task RegistrarRetiroAsync(Guid actorId, int anio, string cedula, RegistrarRetiroRequest request)
    {
        var (estado, anteriores) = await repo.RegistrarRetiroAsync(actorId, anio, cedula, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.RegistrarRetiroMatricula, Tabla, IdRegistro(anio, cedula),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU26: anula el retiro. Registra log solo si tenía uno.</summary>
    public async Task AnularRetiroAsync(Guid actorId, int anio, string cedula)
    {
        var (estado, anteriores) = await repo.AnularRetiroAsync(actorId, anio, cedula);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.AnularRetiroMatricula, Tabla, IdRegistro(anio, cedula),
                datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>CU28: elimina la matrícula (corrección de errores).</summary>
    public async Task EliminarAsync(Guid actorId, int anio, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, anio, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarMatricula, Tabla, IdRegistro(anio, cedula),
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Profesor Regular CU04 / Guía CU02: estudiantes de una sección donde imparte o es guía.</summary>
    public Task<List<Matricula>> ListarEstudiantesSeccionAsync(Guid idUsuario, int anio, int nivel, int numero) =>
        repo.ListarEstudiantesSeccionAsync(idUsuario, anio, nivel, numero);
}
