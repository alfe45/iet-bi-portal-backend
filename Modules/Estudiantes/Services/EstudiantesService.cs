using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Texto;
using iet_bi_portal_backend.Modules.Estudiantes.Data;
using iet_bi_portal_backend.Modules.Estudiantes.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Estudiantes.Services;

public class EstudiantesService(EstudiantesRepository repo, ILogsService logs)
{
    private const string Tabla = "academico.estudiantes";

    /// <summary>CU10: registra un estudiante. Devuelve la cédula normalizada. Reglas validadas por la DB.</summary>
    public async Task<string> RegistrarAsync(Guid actorId, RegistrarEstudianteRequest request)
    {
        request.Email = request.Email.NormalizarEmail();
        var cedula = await repo.RegistrarAsync(actorId, request);

        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarEstudiante, Tabla, cedula, datosNuevos: request);
        return cedula;
    }

    /// <summary>CU11: listado paginado con búsqueda opcional (nombre, apellidos, cédula o correo).</summary>
    public Task<ResultadoPaginado<EstudianteAdmin>> ListarAsync(ConsultaConBusqueda consulta) => repo.ListarAsync(consulta);

    /// <summary>CU11: detalle por cédula, o null si no existe.</summary>
    public Task<EstudianteAdmin?> ObtenerAsync(string cedula) => repo.ObtenerAsync(cedula);

    /// <summary>CU12: modifica un estudiante. Registra snapshot previo y datos nuevos solo si hubo cambios.</summary>
    public async Task ActualizarAsync(Guid actorId, string cedula, ActualizarEstudianteRequest request)
    {
        request.Email = request.Email.NormalizarEmail();
        var (estado, anteriores) = await repo.ActualizarAsync(actorId, cedula, request);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarEstudiante, Tabla, cedula,
                datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>CU13: elimina un estudiante.</summary>
    public async Task EliminarAsync(Guid actorId, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarEstudiante, Tabla, cedula, datosAnteriores: anteriores.ComoJson());
    }
}
