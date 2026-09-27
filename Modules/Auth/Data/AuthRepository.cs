using Npgsql;
using iet_bi_portal_backend.Modules.Auth.Models;

namespace iet_bi_portal_backend.Modules.Auth.Data;

public class AuthRepository
{
    private const string UserColumns = "id_usuario, email, password_hash, activo, bloqueado_hasta, roles::text[]";

    private readonly NpgsqlDataSource _db;

    public AuthRepository(NpgsqlDataSource db) => _db = db;

    /// <summary> Registra un nuevo usuario con rol PROFESOR_REGULAR. 
    /// Devuelve el ID del usuario si se creó correctamente, o null si el correo ya está en uso. </summary>
    public async Task<Guid?> RegisterUserAsync(string email, string passwordHash)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_registrar_usuario($1::academico.citext, $2)");
        cmd.Parameters.AddWithValue(email);
        cmd.Parameters.AddWithValue(passwordHash);
        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id ? id : null;
    }

    /// <summary> Crea el primer administrador del sistema. La función de base de datos serializa
    /// los intentos concurrentes con un advisory lock transaccional y falla (PostgresException,
    /// SqlState P0001) si ya existe un admin inicial o si el correo ya está en uso. </summary>
    public async Task<Guid> CreateFirstAdminAsync(string email, string passwordHash)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_crear_primer_admin($1::academico.citext, $2)");
        cmd.Parameters.AddWithValue(email);
        cmd.Parameters.AddWithValue(passwordHash);
        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id
            ? id
            : throw new InvalidOperationException("Respuesta inesperada de fn_crear_primer_admin.");
    }

    /// <summary> Obtiene un usuario por su correo electrónico. </summary>
    public Task<UserRecord?> GetUserByEmailAsync(string email) =>
        QueryUserAsync($"SELECT {UserColumns} FROM auth.fn_obtener_usuario_por_email($1::academico.citext)", email);

    /// <summary> Obtiene un usuario por su ID. </summary>
    public Task<UserRecord?> GetUserByIdAsync(Guid id) =>
        QueryUserAsync($"SELECT {UserColumns} FROM auth.fn_obtener_usuario_por_id($1)", id);

    /// <summary> Registra un intento fallido de inicio de sesión. </summary>
    public Task RegisterFailedLoginAsync(Guid userId, int maxAttempts, int lockoutMinutes) =>
        CallAsync("CALL auth.sp_registrar_login_fallido($1, $2, $3)", userId, maxAttempts, lockoutMinutes);

    /// <summary> Registra un intento exitoso de inicio de sesión. </summary>
    public Task RegisterSuccessfulLoginAsync(Guid userId) =>
        CallAsync("CALL auth.sp_registrar_login_exitoso($1)", userId);

    /// <summary> Cambia la contraseña del usuario. </summary>
    public Task ChangePasswordAsync(Guid userId, string newPasswordHash) =>
        CallAsync("CALL auth.sp_cambiar_contrasena($1, $2)", userId, newPasswordHash);

    /// <summary> Crea una nueva sesión para el usuario. </summary>
    public Task CreateSessionAsync(Guid userId, string tokenHash, DateTime expiresAtUtc, string? ip, string? userAgent) =>
        CallAsync("CALL auth.sp_crear_sesion($1, $2, $3, $4::text, $5::text)", userId, tokenHash, expiresAtUtc, ip, userAgent);

    /// <summary> Rota una sesión existente, reemplazando el refresh token antiguo por uno nuevo. </summary>
    public async Task<RotateResult> RotateSessionAsync(string oldTokenHash, string newTokenHash, DateTime newExpiresAtUtc, string? ip, string? userAgent)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT out_status, out_user_id, out_email, out_roles::text[] " +
            "FROM auth.fn_rotar_sesion($1, $2, $3, $4::text, $5::text)");
        cmd.Parameters.AddWithValue(oldTokenHash);
        cmd.Parameters.AddWithValue(newTokenHash);
        cmd.Parameters.AddWithValue(newExpiresAtUtc);
        cmd.Parameters.AddWithValue((object?)ip ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)userAgent ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();

        var status = reader.GetString(0);
        AuthenticatedUser? user = reader.IsDBNull(1)
            ? null
            : new AuthenticatedUser(
                reader.GetGuid(1),
                reader.GetString(2),
                reader.IsDBNull(3) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(3));

        return new RotateResult(status, user);
    }

    /// <summary> Cierra la sesión del usuario. </summary>
    public Task LogoutAsync(string tokenHash) => CallAsync("CALL auth.sp_logout($1)", tokenHash);

    /// <summary> Cierra todas las sesiones del usuario. </summary>
    public Task LogoutAllAsync(Guid userId) => CallAsync("CALL auth.sp_logout_all($1)", userId);

    /// <summary> Elimina las sesiones expiradas. </summary>
    public Task PurgeExpiredSessionsAsync() => CallAsync("CALL auth.sp_purgar_sesiones_expiradas()");

    /// <summary>Fecha desde la cual los tokens emitidos antes deben considerarse revocados (logout-all, cambio de contraseña o cambio de roles). Null si nunca se invalidó nada.</summary>
    public async Task<DateTime?> GetTokenInvalidationWatermarkAsync(Guid userId)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT tokens_invalidados_desde FROM api.usuarios WHERE id_usuario = $1");
        cmd.Parameters.AddWithValue(userId);
        var result = await cmd.ExecuteScalarAsync();
        return result is DateTime dt ? dt : null;
    }

    /// <summary> Consulta un usuario y devuelve un UserRecord o null si no existe. </summary>
    private async Task<UserRecord?> QueryUserAsync(string sql, object param)
    {
        await using var cmd = _db.CreateCommand(sql);
        cmd.Parameters.AddWithValue(param);
        await using var reader = await cmd.ExecuteReaderAsync();

        if (!await reader.ReadAsync()) return null;

        return new UserRecord(
            reader.GetGuid(0),
            reader.GetString(1),
            reader.GetString(2),
            reader.GetBoolean(3),
            reader.IsDBNull(4) ? null : reader.GetDateTime(4),
            reader.IsDBNull(5) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(5));
    }

    /// <summary> Llama a una función de base de datos y devuelve su resultado. </summary>
    private async Task CallAsync(string sql, params object?[] args)
    {
        await using var cmd = _db.CreateCommand(sql);
        foreach (var arg in args)
            cmd.Parameters.AddWithValue(arg ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
    }
}