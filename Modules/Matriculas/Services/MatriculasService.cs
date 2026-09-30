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

    /// <summary>CU22: matricula al estudiante en la sección.</summary>
    public async Task RegistrarAsync(Guid actorId, RegistrarMatriculaRequest request)
    {
        await repo.RegistrarAsync(actorId, request);
        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarMatricula, Tabla,
            IdRegistro(request.Anio!.Value, request.CedulaEstudiante), datosNuevos: request);
    }

    /// <summary>CU22 - Subir la sección: matrícula masiva en 11-N. Registra log solo si creó la sección o matriculó a alguien.</summary>
    public async Task<SeccionSubida> SubirSeccionAsync(Guid actorId, SubirSeccionRequest request)
    {
        var resultado = await repo.SubirSeccionAsync(actorId, request);
        if (resultado.SeccionCreada || resultado.Matriculados.Length > 0)
            await logs.RegistrarAsync(actorId, AccionesLog.SubirSeccion, Tabla, $"{request.Anio}/11-{request.Numero}",
                datosNuevos: new { request.FechaMatricula, resultado.SeccionCreada, resultado.Matriculados });
        return resultado;
    }

    /// <summary>CU24: listado / historial paginado con filtros opcionales.</summary>
    public Task<ResultadoPaginado<Matricula>> ListarAsync(ConsultaMatriculas consulta) => repo.ListarAsync(consulta);

    /// <summary>CU24: detalle, o null si no existe.</summary>
    public Task<Matricula?> ObtenerAsync(int anio, string cedula) => repo.ObtenerAsync(anio, cedula);

    /// <summary>CU23: traslado a otra sección del mismo año. Registra log solo si hubo cambios.</summary>
    public async Task CambiarSeccionAsync(Guid actorId, int anio, string cedula, CambiarSeccionRequest request)
    {
        var (estado, anteriores) = await repo.CambiarSeccionAsync(actorId, anio, cedula, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.CambiarSeccionMatricula, Tabla, IdRegistro(anio, cedula),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU23: registra o corrige el retiro. Registra log solo si hubo cambios.</summary>
    public async Task RegistrarRetiroAsync(Guid actorId, int anio, string cedula, RegistrarRetiroRequest request)
    {
        var (estado, anteriores) = await repo.RegistrarRetiroAsync(actorId, anio, cedula, request);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.RegistrarRetiroMatricula, Tabla, IdRegistro(anio, cedula),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU23: anula el retiro. Registra log solo si tenía uno.</summary>
    public async Task AnularRetiroAsync(Guid actorId, int anio, string cedula)
    {
        var (estado, anteriores) = await repo.AnularRetiroAsync(actorId, anio, cedula);
        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.AnularRetiroMatricula, Tabla, IdRegistro(anio, cedula),
                datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>CU25: elimina la matrícula (corrección de errores).</summary>
    public async Task EliminarAsync(Guid actorId, int anio, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, anio, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarMatricula, Tabla, IdRegistro(anio, cedula),
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Profesor Regular CU04 / Guía CU02: estudiantes de una sección donde imparte o es guía.</summary>
    public Task<List<Matricula>> ListarEstudiantesSeccionAsync(Guid idUsuario, int anio, int nivel, int numero) =>
        repo.ListarEstudiantesSeccionAsync(idUsuario, anio, nivel, numero);

    /// <summary>Profesor Regular CU05: ficha de un estudiante de una sección donde imparte o es guía.</summary>
    public Task<FichaEstudiante> ObtenerEstudianteSeccionAsync(Guid idUsuario, int anio, int nivel, int numero, string cedula) =>
        repo.ObtenerEstudianteSeccionAsync(idUsuario, anio, nivel, numero, cedula);
}
