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

    /// <summary>CU01: registra un profesor con su cuenta (RN-05). Devuelve la cédula normalizada.</summary>
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

    /// <summary>CU01: crea la cuenta de un profesor que no tiene (registrado antes de que fuera obligatoria). Devuelve el id del usuario.</summary>
    public async Task<Guid> CrearCuentaAsync(Guid actorId, string cedula, CuentaProfesorRequest cuenta)
    {
        var idUsuario = await repo.CrearCuentaAsync(actorId, cedula, cuenta, Hash(cuenta));

        await logs.RegistrarAsync(actorId, AccionesLog.CrearCuentaProfesor, Tabla, cedula,
            datosNuevos: new { idUsuario, cuenta.Email, cuenta.Roles });
        return idUsuario;
    }

    private string? Hash(CuentaProfesorRequest? cuenta) =>
        string.IsNullOrEmpty(cuenta?.Contrasena) ? null : contrasenas.Hashear(cuenta.Contrasena);

    /// <summary>CU02: listado paginado con búsqueda opcional (nombre, apellidos, cédula o correo).</summary>
    public Task<ResultadoPaginado<ProfesorAdmin>> ListarAsync(Guid actorId, ConsultaConBusqueda consulta) => repo.ListarAsync(actorId, consulta);

    /// <summary>CU02: detalle por cédula, o null si no existe.</summary>
    public Task<ProfesorAdmin?> ObtenerAsync(Guid actorId, string cedula) => repo.ObtenerAsync(actorId, cedula);

    /// <summary>CU03: modifica un profesor y, si viene, su cuenta. Corre en la transacción de la petición (RP-58): datos y
    /// cuenta se confirman juntos o no se aplica nada (RD-010). Audita cada parte solo si cambió.</summary>
    public async Task ActualizarAsync(Guid actorId, string cedula, ModificarProfesorRequest request)
    {
        var (estado, anteriores) = await repo.ActualizarAsync(actorId, cedula, request);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarProfesor, Tabla, cedula,
                datosAnteriores: anteriores.ComoJson(), datosNuevos: new
                {
                    request.Nombre, request.PrimerApellido, request.SegundoApellido, request.NumeroCelular, request.FechaNacimiento
                });

        if (request.Cuenta is not { } cuenta) return;

        var hash = cuenta.Contrasena is null ? null : contrasenas.Hashear(cuenta.Contrasena);
        var (estadoCuenta, cuentaAnterior, idUsuario, creada) = await repo.ActualizarCuentaAsync(actorId, cedula, cuenta, hash);

        if (creada)
            await logs.RegistrarAsync(actorId, AccionesLog.CrearCuentaProfesor, Tabla, cedula,
                datosNuevos: new { idUsuario, cuenta.Email, cuenta.Roles });
        else if (estadoCuenta == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, AccionesLog.ModificarCuentaProfesor, Tabla, cedula,
                datosAnteriores: cuentaAnterior.ComoJson(), datosNuevos: cuenta.ParaLog());
    }

    /// <summary>CU04: elimina el perfil de profesor y su cuenta (RN-07).</summary>
    public async Task EliminarAsync(Guid actorId, string cedula)
    {
        var anteriores = await repo.EliminarAsync(actorId, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarProfesor, Tabla, cedula, datosAnteriores: anteriores.ComoJson());
    }
}
