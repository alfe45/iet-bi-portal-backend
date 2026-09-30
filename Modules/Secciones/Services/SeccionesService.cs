using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Secciones.Data;
using iet_bi_portal_backend.Modules.Secciones.Models;

namespace iet_bi_portal_backend.Modules.Secciones.Services;

public class SeccionesService(SeccionesRepository repo, ILogsService logs)
{
    private const string Tabla = "academico.secciones";

    /// <summary>Identificador de auditoría: "2026/10-1".</summary>
    private static string IdRegistro(int anio, int nivel, int numero) => $"{anio}/{nivel}-{numero}";

    /// <summary>CU18: registra una sección. Devuelve su nombre ("10-1").</summary>
    public async Task<string> RegistrarAsync(Guid actorId, RegistrarSeccionRequest request)
    {
        var nombre = await repo.RegistrarAsync(actorId, request);

        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarSeccion, Tabla,
            IdRegistro(request.Anio!.Value, request.Nivel!.Value, request.Numero!.Value), datosNuevos: request);
        return nombre;
    }

    /// <summary>CU19: listado paginado con filtros opcionales.</summary>
    public Task<ResultadoPaginado<Seccion>> ListarAsync(ConsultaSecciones consulta) => repo.ListarAsync(consulta);

    /// <summary>CU19: detalle, o null si no existe.</summary>
    public Task<Seccion?> ObtenerAsync(int anio, int nivel, int numero) => repo.ObtenerAsync(anio, nivel, numero);

    /// <summary>CU20: elimina una sección.</summary>
    public async Task EliminarAsync(Guid actorId, int anio, int nivel, int numero)
    {
        var anteriores = await repo.EliminarAsync(actorId, anio, nivel, numero);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarSeccion, Tabla, IdRegistro(anio, nivel, numero),
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>CU21: asocia (o reemplaza) el profesor guía. Registra log solo si hubo cambios.</summary>
    public async Task AsignarGuiaAsync(Guid actorId, int anio, int nivel, int numero, AsignarGuiaRequest request)
    {
        var (estado, anteriores) = await repo.AsignarGuiaAsync(actorId, anio, nivel, numero, request.CedulaProfesor);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.AsignarGuia, Tabla, IdRegistro(anio, nivel, numero),
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU21: quita el profesor guía. Registra log solo si tenía uno.</summary>
    public async Task QuitarGuiaAsync(Guid actorId, int anio, int nivel, int numero)
    {
        var (estado, anteriores) = await repo.QuitarGuiaAsync(actorId, anio, nivel, numero);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.QuitarGuia, Tabla, IdRegistro(anio, nivel, numero),
                datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Guía CU01: secciones de las que el profesor es guía en un año (null = periodo en curso).</summary>
    public Task<List<Seccion>> ListarMisSeccionesGuiaAsync(Guid idUsuario, int? anio) =>
        repo.ListarMisSeccionesGuiaAsync(idUsuario, anio);
}
