using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Profesores.Data;
using iet_bi_portal_backend.Modules.Profesores.Models;

namespace iet_bi_portal_backend.Modules.Profesores.Services;

public class ProfesoresService(ProfesoresRepository repo, ILogsService logs)
{
    private const string Tabla = "academico.profesores";

    /// <summary>CU06: registra un profesor vinculado a un usuario existente. Devuelve la cédula normalizada.</summary>
    public async Task<string> RegistrarAsync(Guid actorId, RegistrarProfesorRequest request)
    {
        var cedula = await repo.RegistrarAsync(actorId, request);

        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarProfesor, Tabla, cedula, datosNuevos: request);
        return cedula;
    }

    /// <summary>CU07: listado paginado con búsqueda opcional (nombre, apellidos, cédula o correo).</summary>
    public Task<ResultadoPaginado<ProfesorAdmin>> ListarAsync(Guid actorId, ConsultaConBusqueda consulta) => repo.ListarAsync(actorId, consulta);

    /// <summary>CU07: detalle por cédula, o null si no existe.</summary>
    public Task<ProfesorAdmin?> ObtenerAsync(Guid actorId, string cedula) => repo.ObtenerAsync(actorId, cedula);

    /// <summary>CU08: modifica un profesor. Registra snapshot previo y datos nuevos solo si hubo cambios.</summary>
    public async Task ActualizarAsync(Guid actorId, string cedula, ActualizarProfesorRequest request)
    {
        var (estado, anteriores) = await repo.ActualizarAsync(actorId, cedula, request);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarProfesor, Tabla, cedula,
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU09: elimina el perfil de profesor (el usuario se conserva, RN-07).</summary>
    public async Task EliminarAsync(Guid actorId, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarProfesor, Tabla, cedula, datosAnteriores: anteriores.ComoJson());
    }
}
