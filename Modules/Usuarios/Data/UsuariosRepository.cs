using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Usuarios.Models;

namespace iet_bi_portal_backend.Modules.Usuarios.Data;

/// <summary>Acceso a las funciones de administración de usuarios (CU01 a CU05). Las reglas las valida la DB.</summary>
public class UsuariosRepository(NpgsqlDataSource db)
{
    private const string Columnas =
        "id_usuario, email, activo, bloqueado_hasta, ultimo_login, creado_en, roles::text[], cantidad_sesiones, " +
        "cedula_profesor, nombre_profesor";

    public Task<Guid> RegistrarAsync(Guid actorId, string email, string contrasenaHash) =>
        db.EscalarAsync<Guid>(
            "SELECT auth.fn_admin_registrar_usuario($1, $2::academico.citext, $3)", actorId, email, contrasenaHash);

    public async Task<ResultadoPaginado<UsuarioAdmin>> ListarAsync(Guid actorId, ConsultaUsuarios c)
    {
        var rol = c.Rol?.ToUpperInvariant();
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM auth.fn_admin_listar_usuarios($1, $2::text, $3::api.roles, $4, $5)",
            Leer, actorId, c.Busqueda, rol, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>(
            "SELECT auth.fn_admin_contar_usuarios($1, $2::text, $3::api.roles)", actorId, c.Busqueda, rol);
        return new ResultadoPaginado<UsuarioAdmin>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    /// <summary>Perfil propio (cualquier autenticado).</summary>
    public Task<UsuarioAdmin?> ObtenerAsync(Guid id) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM auth.fn_obtener_usuario_detalle($1)", Leer, id);

    /// <summary>Detalle de un usuario para el ADMIN (la DB valida el actor, RP-12).</summary>
    public Task<UsuarioAdmin?> ObtenerAdminAsync(Guid actorId, Guid id) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM auth.fn_admin_obtener_usuario($1, $2)", Leer, actorId, id);

    public Task<(string Estado, string EmailAnterior)> ActualizarEmailAsync(Guid actorId, Guid idObjetivo, string email) =>
        db.PrimeroAsync(
            "SELECT out_status, out_email_anterior FROM auth.fn_admin_actualizar_email($1, $2, $3::academico.citext)",
            r => (r.GetString(0), r.GetString(1)),
            actorId, idObjetivo, email);

    public Task ResetearContrasenaAsync(Guid actorId, Guid idObjetivo, string contrasenaHash) =>
        db.EjecutarAsync("CALL auth.sp_admin_resetear_contrasena($1, $2, $3)", actorId, idObjetivo, contrasenaHash);

    public Task<string> CambiarEstadoAsync(Guid actorId, Guid idObjetivo, bool activo) =>
        db.EscalarAsync<string>("SELECT auth.fn_admin_cambiar_estado_usuario($1, $2, $3)", actorId, idObjetivo, activo);

    public Task<string> AsignarRolAsync(Guid actorId, Guid idObjetivo, string rol) =>
        db.EscalarAsync<string>("SELECT auth.fn_admin_asignar_rol($1, $2, $3::api.roles)", actorId, idObjetivo, rol);

    public Task<string> RevocarRolAsync(Guid actorId, Guid idObjetivo, string rol) =>
        db.EscalarAsync<string>("SELECT auth.fn_admin_revocar_rol($1, $2, $3::api.roles)", actorId, idObjetivo, rol);

    /// <summary>Elimina el usuario y devuelve su email y roles previos (para auditoría).</summary>
    public Task<(string Email, string[] Roles)> EliminarAsync(Guid actorId, Guid idObjetivo) =>
        db.PrimeroAsync(
            "SELECT out_email, out_roles::text[] FROM auth.fn_admin_eliminar_usuario($1, $2)",
            r => (r.GetString(0), r.GetFieldValue<string[]>(1)),
            actorId, idObjetivo);

    private static UsuarioAdmin Leer(NpgsqlDataReader r) => new(
        r.GetGuid(0),
        r.GetString(1),
        r.GetBoolean(2),
        r.IsDBNull(3) ? null : r.GetDateTime(3),
        r.IsDBNull(4) ? null : r.GetDateTime(4),
        r.GetDateTime(5),
        r.GetFieldValue<string[]>(6),
        r.GetInt64(7),
        r.IsDBNull(8) ? null : r.GetString(8),
        r.IsDBNull(9) ? null : r.GetString(9));
}
