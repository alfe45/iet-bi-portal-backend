using Microsoft.Extensions.Options;
using Npgsql;
using iet_bi_portal_backend.Security;
using iet_bi_portal_backend.Modules.Auth.Data;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Settings;

namespace iet_bi_portal_backend.Modules.Auth.Services;

public class AuthService
{
    private const string PostgresInvalidTextRepresentation = "22P02";
    private const string PostgresRaiseException = "P0001";
    private const string PostgresUniqueViolation = "23505";

    private readonly AuthRepository _repo;
    private readonly IPasswordService _passwords;
    private readonly ITokenService _tokens;
    private readonly JwtOptions _jwt;
    private readonly AuthPolicyOptions _policy;

    public AuthService(
        AuthRepository repo,
        IPasswordService passwords,
        ITokenService tokens,
        IOptions<JwtOptions> jwt,
        IOptions<AuthPolicyOptions> policy)
    {
        _repo = repo;
        _passwords = passwords;
        _tokens = tokens;
        _jwt = jwt.Value;
        _policy = policy.Value;
    }

    /// <summary> Registra un nuevo usuario con rol PROFESOR. 
    /// Devuelve 201 Created con el access token y refresh token si se creó correctamente, 
    /// o 409 Conflict si el correo ya está en uso. </summary>
    public async Task<AuthResponse?> RegisterAsync(string email, string password, ClientInfo client)
    {
        email = NormalizeEmail(email);
        var userId = await _repo.RegisterUserAsync(email, _passwords.Hash(password));
        if (userId is null) return null;

        // fn_registrar_usuario ya le asignó PROFESOR en la DB; se refleja acá también
        // para no hacer una consulta extra solo para leer el rol recién creado.
        return await IssueSessionAsync(userId.Value, email, new[] { Roles.Profesor }, client);
    }

    /// <summary> Inicia sesión con correo y contraseña. 
    /// Devuelve 200 OK con el access token y refresh token si las credenciales son correctas, 
    /// o 401 Unauthorized si no lo son. </summary>
    public async Task<AuthResponse?> LoginAsync(string email, string password, ClientInfo client)
    {
        email = NormalizeEmail(email);
        var user = await _repo.GetUserByEmailAsync(email);

        if (user is null || !user.IsActive || user.LockoutUntil > DateTime.UtcNow)
        {
            _passwords.VerifyDummy(password);
            return null;
        }

        if (!_passwords.Verify(password, user.PasswordHash))
        {
            await _repo.RegisterFailedLoginAsync(user.Id, _policy.MaxFailedAttempts, _policy.LockoutMinutes);
            return null;
        }

        await _repo.RegisterSuccessfulLoginAsync(user.Id);
        return await IssueSessionAsync(user.Id, user.Email, user.Roles, client);
    }

    /// <summary> Renueva el access token usando el refresh token. 
    /// Devuelve 200 OK con el nuevo access token y refresh token si la operación es exitosa,
    /// o 401 Unauthorized si el refresh token es inválido o ha expirado. </summary>
    public async Task<AuthResponse?> RefreshAsync(string refreshToken, ClientInfo client)
    {
        var newRefreshToken = _tokens.GenerateRefreshToken();

        var result = await _repo.RotateSessionAsync(
            _tokens.Hash(refreshToken),
            _tokens.Hash(newRefreshToken),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays),
            client.Ip,
            client.UserAgent);

        if (result.Status != "ok" || result.User is null) return null;

        var access = _tokens.CreateAccessToken(result.User.Id, result.User.Email, result.User.Roles);
        return new AuthResponse(access.Token, access.ExpiresAt, newRefreshToken);
    }

    /// <summary> Cierra la sesión del usuario. </summary>
    public Task LogoutAsync(string refreshToken) => _repo.LogoutAsync(_tokens.Hash(refreshToken));

    /// <summary> Cierra todas las sesiones del usuario. </summary>
    public Task LogoutAllAsync(Guid userId) => _repo.LogoutAllAsync(userId);

    /// <summary> Cambia la contraseña del usuario. </summary>
    public async Task<bool> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword)
    {
        var user = await _repo.GetUserByIdAsync(userId);
        if (user is null || !user.IsActive || !_passwords.Verify(currentPassword, user.PasswordHash))
            return false;

        await _repo.ChangePasswordAsync(userId, _passwords.Hash(newPassword));
        return true;
    }

    /// <summary>
    /// Crea el primer administrador del sistema. Solo puede tener éxito una vez: la propia
    /// base de datos garantiza (con un advisory lock transaccional + una tabla singleton)
    /// que dos solicitudes concurrentes no puedan crear dos administradores iniciales.
    /// </summary>
    public async Task<BootstrapAdminResult> BootstrapAdminAsync(string email, string password)
    {
        email = NormalizeEmail(email);

        try
        {
            var userId = await _repo.CreateFirstAdminAsync(email, _passwords.Hash(password));
            return new BootstrapAdminResult(BootstrapAdminStatus.Ok, userId);
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresRaiseException)
        {
            if (ex.MessageText.Contains("ya fue creado", StringComparison.OrdinalIgnoreCase))
                return new BootstrapAdminResult(BootstrapAdminStatus.AlreadyExists);

            if (ex.MessageText.Contains("ya existe", StringComparison.OrdinalIgnoreCase))
                return new BootstrapAdminResult(BootstrapAdminStatus.EmailTaken);

            throw;
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresUniqueViolation)
        {
            // Red de seguridad adicional: el advisory lock ya debería evitar que dos
            // transacciones lleguen a chocar acá, pero si de todas formas ocurriera,
            // esto evita un 500 y responde con algo significativo para el cliente.
            return new BootstrapAdminResult(
                ex.ConstraintName == "uq_usuarios_email"
                    ? BootstrapAdminStatus.EmailTaken
                    : BootstrapAdminStatus.AlreadyExists);
        }
    }
    /// <summary>
    /// Emite una nueva sesión para el usuario.
    /// </summary>
    private async Task<AuthResponse> IssueSessionAsync(Guid userId, string email, IReadOnlyList<string> roles, ClientInfo client)
    {
        var refreshToken = _tokens.GenerateRefreshToken();

        await _repo.CreateSessionAsync(
            userId,
            _tokens.Hash(refreshToken),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays),
            client.Ip,
            client.UserAgent);

        var access = _tokens.CreateAccessToken(userId, email, roles);
        return new AuthResponse(access.Token, access.ExpiresAt, refreshToken);
    }

    /// <summary> Normaliza el correo electrónico para comparaciones y búsquedas. </summary>
    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    /// <summary>Otorga <paramref name="role"/> a <paramref name="targetUserId"/>. Requiere que <paramref name="actorUserId"/> sea ADMIN activo (lo valida la DB).</summary>
    public Task<ChangeRoleResult> AssignRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        ExecuteRoleChangeAsync(() => _repo.AssignRoleAsync(actorUserId, targetUserId, role));

    /// <summary>Quita <paramref name="role"/> de <paramref name="targetUserId"/>. No permite dejarlo sin roles.</summary>
    public Task<ChangeRoleResult> RevokeRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        ExecuteRoleChangeAsync(() => _repo.RevokeRoleAsync(actorUserId, targetUserId, role));

    /// <summary> Ejecuta una función de cambio de rol y traduce los resultados a ChangeRoleResult. </summary>
    private static async Task<ChangeRoleResult> ExecuteRoleChangeAsync(Func<Task<string>> action)
    {
        try
        {
            var status = await action();
            return status switch
            {
                "OK" => ChangeRoleResult.Ok,
                "SIN_CAMBIOS" => ChangeRoleResult.NoChange,
                // Antes: "_ => ChangeRoleResult.Ok" trataba cualquier respuesta desconocida
                // de la función SQL como éxito silencioso. Si el contrato de la función
                // cambia algún día, mejor fallar ruidosamente que reportar un éxito falso.
                _ => throw new InvalidOperationException($"Respuesta inesperada de la función de roles: '{status}'.")
            };
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresRaiseException)
        {
            if (ex.MessageText.Contains("permisos", StringComparison.OrdinalIgnoreCase))
                return ChangeRoleResult.Forbidden;

            if (ex.MessageText.Contains("no existe", StringComparison.OrdinalIgnoreCase))
                return ChangeRoleResult.NotFound;

            if (ex.MessageText.Contains("único rol", StringComparison.OrdinalIgnoreCase))
                return ChangeRoleResult.CannotRemoveLastRole;

            throw;
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresInvalidTextRepresentation)
        {
            return ChangeRoleResult.InvalidRole;
        }
    }
}

/// <summary> Resultado de la rotación de sesión. </summary>
public enum ChangeRoleResult
{
    Ok,
    NoChange,
    Forbidden,
    NotFound,
    InvalidRole,
    CannotRemoveLastRole
}

/// <summary> Estado de la creación del primer administrador. </summary>
public enum BootstrapAdminStatus
{
    Ok,
    AlreadyExists,
    EmailTaken
}

/// <summary> Resultado de la creación del primer administrador. </summary>
public record BootstrapAdminResult(BootstrapAdminStatus Status, Guid? UserId = null);
