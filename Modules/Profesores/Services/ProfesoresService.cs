using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Profesores.Data;
using iet_bi_portal_backend.Modules.Profesores.Models;

namespace iet_bi_portal_backend.Modules.Profesores.Services;

public class ProfesoresService(ProfesoresRepository repo, IContrasenaService contrasenas, ILogsService logs)
{
    private const string Tabla = "academico.profesores";

    /// <summary>CU06: registra un profesor con cuenta opcional (RN-05). Devuelve la cédula normalizada.</summary>
    public async Task<string> RegistrarAsync(Guid actorId, RegistrarProfesorRequest request)
    {
        var cedula = await repo.RegistrarAsync(actorId, request, Hash(request.Cuenta));

        await logs.RegistrarAsync(actorId, AccionesLog.RegistrarProfesor, Tabla, cedula, datosNuevos: new
        {
            request.Nombre, request.PrimerApellido, request.SegundoApellido, request.Cedula, request.NumeroCelular,
            request.FechaNacimiento, Cuenta = request.Cuenta?.ParaLog()   // nunca la contraseña
        });
        return cedula;
    }

    /// <summary>CU06: crea o vincula la cuenta de un profesor que no tiene. Devuelve el id del usuario.</summary>
    public async Task<Guid> CrearCuentaAsync(Guid actorId, string cedula, CuentaProfesorRequest cuenta)
    {
        var idUsuario = await repo.CrearCuentaAsync(actorId, cedula, cuenta, Hash(cuenta));

        await logs.RegistrarAsync(actorId, AccionesLog.CrearCuentaProfesor, Tabla, cedula,
            datosNuevos: new { idUsuario, cuenta.Email, cuenta.Roles, vinculada = cuenta.IdUsuario is not null });
        return idUsuario;
    }

    /// <summary>CU09: quita (elimina) la cuenta del profesor; el profesor se conserva (RN-07).</summary>
    public async Task QuitarCuentaAsync(Guid actorId, string cedula)
    {
        var (idUsuario, email, roles) = await repo.QuitarCuentaAsync(actorId, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.QuitarCuentaProfesor, Tabla, cedula,
            datosAnteriores: new { idUsuario, email, roles });
    }

    private string? Hash(CuentaProfesorRequest? cuenta) =>
        string.IsNullOrEmpty(cuenta?.Contrasena) ? null : contrasenas.Hashear(cuenta.Contrasena);

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

    /// <summary>CU09: elimina el perfil de profesor (su cuenta, si tiene, se conserva, RN-07).</summary>
    public async Task EliminarAsync(Guid actorId, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarProfesor, Tabla, cedula, datosAnteriores: anteriores.ComoJson());
    }
}
