using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Common.Texto;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Usuarios.Models;
using iet_bi_portal_backend.Modules.Usuarios.Data;

namespace iet_bi_portal_backend.Modules.Usuarios.Services;

public class UsuariosService(UsuariosRepository repo, ILogsService logs, IContrasenaService contrasenas)
{
    private const string TablaUsuarios = "api.usuarios";
    private const string TablaRoles = "api.usuario_roles";

    /// <summary>CU02: registra un usuario con rol PROFESOR_REGULAR. No emite sesión.</summary>
    public async Task<(Guid Id, string Email)> RegistrarAsync(Guid actorId, string email, string contrasena)
    {
        email = email.NormalizarEmail();
        var id = await repo.RegistrarAsync(actorId, email, contrasenas.Hashear(contrasena));

        await logs.RegistrarAsync(actorId, "CREATE_USER", TablaUsuarios, id.ToString(),
            datosNuevos: new { email, roles = new[] { Roles.ProfesorRegular } });

        return (id, email);
    }

    /// <summary>CU03: listado paginado, sin filtros (los aplica el frontend).</summary>
    public Task<ResultadoPaginado<UsuarioAdmin>> ListarAsync(int pagina, int tamanoPagina) =>
        repo.ListarAsync(pagina, tamanoPagina);

    /// <summary>CU01 / CU03: detalle de un usuario, o null si no existe.</summary>
    public Task<UsuarioAdmin?> ObtenerAsync(Guid id) => repo.ObtenerAsync(id);

    /// <summary>CU04: modifica el email. Registra auditoría solo si hubo cambios.</summary>
    public async Task ActualizarEmailAsync(Guid actorId, Guid idObjetivo, string emailNuevo)
    {
        emailNuevo = emailNuevo.NormalizarEmail();
        var (estado, emailAnterior) = await repo.ActualizarEmailAsync(actorId, idObjetivo, emailNuevo);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, "UPDATE_USER_EMAIL", TablaUsuarios, idObjetivo.ToString(),
                datosAnteriores: new { email = emailAnterior },
                datosNuevos: new { email = emailNuevo });
    }

    /// <summary>CU04: resetea la contraseña de otro usuario (no requiere la actual: la autoridad es ser ADMIN).</summary>
    public async Task ResetearContrasenaAsync(Guid actorId, Guid idObjetivo, string contrasenaNueva)
    {
        await repo.ResetearContrasenaAsync(actorId, idObjetivo, contrasenas.Hashear(contrasenaNueva));
        await logs.RegistrarAsync(actorId, "RESET_PASSWORD", TablaUsuarios, idObjetivo.ToString());   // nunca el hash
    }

    /// <summary>CU05: activa o desactiva. La DB impide auto-desactivación y dejar el sistema sin admins (AU010/AU011).</summary>
    public async Task CambiarEstadoAsync(Guid actorId, Guid idObjetivo, bool activo)
    {
        var estado = await repo.CambiarEstadoAsync(actorId, idObjetivo, activo);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, activo ? "ACTIVATE_USER" : "DEACTIVATE_USER",
                TablaUsuarios, idObjetivo.ToString());
    }

    /// <summary>CU06: otorga un rol. true si se asignó; false si ya lo tenía.</summary>
    public async Task<bool> AsignarRolAsync(Guid actorId, Guid idObjetivo, string rol)
    {
        rol = rol.ToUpperInvariant();
        var estado = await repo.AsignarRolAsync(actorId, idObjetivo, rol);

        if (estado != EstadoOperacion.Ok) return false;

        await logs.RegistrarAsync(actorId, "ASSIGN_ROLE", TablaRoles, idObjetivo.ToString(),
            datosNuevos: new { rol });
        return true;
    }

    /// <summary>CU06: quita un rol (AU003/AU004/AU005 los valida la DB).</summary>
    public async Task RevocarRolAsync(Guid actorId, Guid idObjetivo, string rol)
    {
        rol = rol.ToUpperInvariant();
        var estado = await repo.RevocarRolAsync(actorId, idObjetivo, rol);

        if (estado == EstadoOperacion.Ok)
            await logs.RegistrarAsync(actorId, "REVOKE_ROLE", TablaRoles, idObjetivo.ToString(),
                datosAnteriores: new { rol });
    }

    /// <summary>CU07: elimina el usuario. Registra email y roles previos, porque después del DELETE no hay nada que consultar.</summary>
    public async Task EliminarAsync(Guid actorId, Guid idObjetivo)
    {
        var (email, roles) = await repo.EliminarAsync(actorId, idObjetivo);

        await logs.RegistrarAsync(actorId, "DELETE_USER", TablaUsuarios, idObjetivo.ToString(),
            datosAnteriores: new { email, roles });
    }
}
