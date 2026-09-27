using Npgsql;
using iet_bi_portal_backend.Modules.Users.Models;

namespace iet_bi_portal_backend.Modules.Users.Data;

/// <summary>Acceso a las funciones de administración de usuarios: alta, consulta, edición
/// de email, reseteo de contraseña, activar/desactivar, asignar/revocar roles y eliminar.
/// Vive en Users, no en Auth: la gestión administrativa de usuarios no es autenticación.
/// Auth no sabe nada de esto.</summary>
public class UsersRepository
{
    private readonly NpgsqlDataSource _db;

    public UsersRepository(NpgsqlDataSource db) => _db = db;

    // ============================================================
    // CU 02 - Registrar usuarios
    // ============================================================

    /// <summary> Crea un usuario con rol PROFESOR_REGULAR. Lanza PostgresException si el
    /// actor no es ADMIN activo (AU009) o si el correo ya está en uso (TA001). </summary>
    public async Task<Guid> RegisterUserAsync(Guid actorUserId, string email, string passwordHash)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_registrar_usuario_admin($1, $2::academico.citext, $3)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(email);
        cmd.Parameters.AddWithValue(passwordHash);
        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id ? id : throw new InvalidOperationException("Respuesta inesperada de fn_registrar_usuario_admin.");
    }

    // ============================================================
    // CU 03 - Consultar usuarios
    // ============================================================

    /// <summary> Lista usuarios paginados (sin filtros) y el total de usuarios en el sistema,
    /// para armar la metadata de paginación. Dos llamadas separadas: si se pide una página
    /// fuera de rango, el total sigue siendo correcto. </summary>
    public async Task<(IReadOnlyList<UserAdminRecord> Items, long TotalCount)> GetUsersPagedAsync(int page, int pageSize)
    {
        var items = new List<UserAdminRecord>();

        await using (var cmd = _db.CreateCommand(
            "SELECT id_usuario, email, activo, bloqueado_hasta, ultimo_login, creado_en, roles::text[], cantidad_sesiones " +
            "FROM auth.fn_listar_usuarios_admin($1, $2)"))
        {
            cmd.Parameters.AddWithValue(page);
            cmd.Parameters.AddWithValue(pageSize);

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                items.Add(ReadUserAdminRecord(reader));
        }

        await using var countCmd = _db.CreateCommand("SELECT auth.fn_contar_usuarios_admin()");
        var total = await countCmd.ExecuteScalarAsync();

        return (items, total is long l ? l : 0);
    }

    /// <summary> Obtiene el detalle de un usuario por su ID, o null si no existe. </summary>
    public async Task<UserAdminRecord?> GetUserByIdAsync(Guid id)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT id_usuario, email, activo, bloqueado_hasta, ultimo_login, creado_en, roles::text[], cantidad_sesiones " +
            "FROM auth.fn_obtener_usuario_admin_por_id($1)");
        cmd.Parameters.AddWithValue(id);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        return ReadUserAdminRecord(reader);
    }

    // ============================================================
    // CU 04 - Modificar usuarios (email) y resetear contraseña
    // ============================================================

    /// <summary> Actualiza el email de un usuario. Devuelve 'OK' o 'SIN_CAMBIOS'; lanza
    /// PostgresException si el actor no es ADMIN (AU009), el objetivo no existe (NF001), o
    /// el correo ya está en uso (TA001). Invalida sesiones y tokens del usuario objetivo. </summary>
    public async Task<string> UpdateEmailAsync(Guid actorUserId, Guid targetUserId, string newEmail)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_admin_actualizar_email($1, $2, $3::academico.citext)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(newEmail);
        var result = await cmd.ExecuteScalarAsync();
        return result as string ?? throw new InvalidOperationException("Respuesta inesperada de fn_admin_actualizar_email.");
    }

    /// <summary> Resetea la contraseña de un usuario (acción de administrador, sin conocer la
    /// contraseña actual). Invalida sesiones y tokens del usuario objetivo. </summary>
    public async Task ResetPasswordAsync(Guid actorUserId, Guid targetUserId, string newPasswordHash)
    {
        await using var cmd = _db.CreateCommand("CALL auth.sp_admin_resetear_contrasena($1, $2, $3)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(newPasswordHash);
        await cmd.ExecuteNonQueryAsync();
    }

    // ============================================================
    // CU 05 - Activar / desactivar usuarios
    // ============================================================

    /// <summary> Activa o desactiva un usuario. Devuelve 'OK' o 'SIN_CAMBIOS'; lanza
    /// PostgresException si el actor no es ADMIN (AU009), el objetivo no existe (NF001), si
    /// un admin intenta desactivarse a sí mismo (AU010), o si sería el último admin activo
    /// (AU011). Al desactivar, revoca sesiones e invalida tokens ya emitidos. </summary>
    public async Task<string> SetActiveAsync(Guid actorUserId, Guid targetUserId, bool activo)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_admin_cambiar_estado_usuario($1, $2, $3)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(activo);
        var result = await cmd.ExecuteScalarAsync();
        return result as string ?? throw new InvalidOperationException("Respuesta inesperada de fn_admin_cambiar_estado_usuario.");
    }

    // ============================================================
    // CU 06 - Asignar / revocar roles
    // ============================================================

    /// <summary> Otorga un rol adicional. Devuelve 'OK' o 'SIN_CAMBIOS'; lanza PostgresException si el actor no es ADMIN o el objetivo no existe. </summary>
    public Task<string> AssignRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        CallRoleFunctionAsync("auth.fn_asignar_rol", actorUserId, targetUserId, role);

    /// <summary> Quita un rol. Devuelve 'OK' o 'SIN_CAMBIOS'; lanza PostgresException si el actor no es ADMIN, el objetivo no existe, o sería el último rol del usuario. </summary>
    public Task<string> RevokeRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        CallRoleFunctionAsync("auth.fn_revocar_rol", actorUserId, targetUserId, role);

    private async Task<string> CallRoleFunctionAsync(string function, Guid actorUserId, Guid targetUserId, string role)
    {
        await using var cmd = _db.CreateCommand($"SELECT {function}($1, $2, $3::api.roles)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(role);
        var result = await cmd.ExecuteScalarAsync();
        return result as string ?? throw new InvalidOperationException($"Respuesta inesperada de {function}.");
    }

    // ============================================================
    // CU 07 - Eliminar usuarios
    // ============================================================

    /// <summary> Elimina físicamente un usuario. Devuelve el email y los roles que tenía justo
    /// antes de borrarlo (para auditoría, ya que después del DELETE no queda nada que
    /// consultar). Lanza PostgresException si el actor no es ADMIN (AU009), el objetivo no
    /// existe (NF001), si un admin intenta eliminarse a sí mismo (AU012), o si sería el
    /// último admin activo (AU013). </summary>
    public async Task<(string Email, IReadOnlyList<string> Roles)> DeleteUserAsync(Guid actorUserId, Guid targetUserId)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT out_email, out_roles::text[] FROM auth.fn_admin_eliminar_usuario($1, $2)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();

        var email = reader.GetString(0);
        var roles = reader.IsDBNull(1) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(1);
        return (email, roles);
    }

    private static UserAdminRecord ReadUserAdminRecord(NpgsqlDataReader reader) => new(
        reader.GetGuid(0),
        reader.GetString(1),
        reader.GetBoolean(2),
        reader.IsDBNull(3) ? null : reader.GetDateTime(3),
        reader.IsDBNull(4) ? null : reader.GetDateTime(4),
        reader.GetDateTime(5),
        reader.IsDBNull(6) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(6),
        reader.GetInt64(7));
}