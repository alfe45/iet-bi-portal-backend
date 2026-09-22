using Microsoft.Extensions.Options;
using iet_bi_portal_backend.Security;
using iet_bi_portal_backend.Modules.Auth.Data;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Settings;

namespace iet_bi_portal_backend.Modules.Auth.Services;

public class AuthService
{
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

    public async Task<AuthResponse?> RegisterAsync(string email, string password, ClientInfo client)
    {
        email = NormalizeEmail(email);
        var userId = await _repo.RegisterUserAsync(email, _passwords.Hash(password));
        if (userId is null) return null;

        return await IssueSessionAsync(userId.Value, email, new[] { Roles.Profesor }, client);
    }

    public async Task<AuthResponse?> LoginAsync(string email, string password, ClientInfo client)
    {
        email = NormalizeEmail(email);
        var user = await _repo.GetUserByEmailAsync(email);

        // Un usuario sin ningún rol asignado (no debería pasar en
        // el flujo normal, pero es posible por edición manual de la DB) se trata
        // igual que credenciales inválidas: fail-closed, sin filtrar el motivo.
        if (user is null || !user.IsActive || user.LockoutUntil > DateTime.UtcNow || user.Roles.Count == 0)
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

    public async Task<AuthResponse?> RefreshAsync(string refreshToken, ClientInfo client)
    {
        var newRefreshToken = _tokens.GenerateRefreshToken();

        var result = await _repo.RotateSessionAsync(
            _tokens.Hash(refreshToken),
            _tokens.Hash(newRefreshToken),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays),
            client.Ip,
            client.UserAgent);

        if (result.Status != "ok" || result.User is null || result.User.Roles.Count == 0) return null;

        var access = _tokens.CreateAccessToken(result.User.Id, result.User.Email, result.User.Roles);
        return new AuthResponse(access.Token, access.ExpiresAt, newRefreshToken);
    }

    public Task LogoutAsync(string refreshToken) => _repo.LogoutAsync(_tokens.Hash(refreshToken));

    public Task LogoutAllAsync(Guid userId) => _repo.LogoutAllAsync(userId);

    public async Task<bool> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword)
    {
        var user = await _repo.GetUserByIdAsync(userId);
        if (user is null || !user.IsActive || !_passwords.Verify(currentPassword, user.PasswordHash))
            return false;

        await _repo.ChangePasswordAsync(userId, _passwords.Hash(newPassword));
        return true;
    }

    /// <summary>Crea el primer administrador. Si ya existe o el correo está en uso, la
    /// excepción de Postgres (AP004/AP005) sube tal cual — la traduce GlobalExceptionHandler.</summary>
    public Task<Guid> BootstrapAdminAsync(string email, string password)
    {
        email = NormalizeEmail(email);
        return _repo.CreateFirstAdminAsync(email, _passwords.Hash(password));
    }

    /// <summary>Otorga un rol. Requiere que el actor sea ADMIN activo (lo valida la DB, AP001/AP002).</summary>
    public Task<string> AssignRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        _repo.AssignRoleAsync(actorUserId, targetUserId, role);

    /// <summary>Quita un rol. No permite dejar al usuario sin roles (AP001/AP002/AP003).</summary>
    public Task<string> RevokeRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        _repo.RevokeRoleAsync(actorUserId, targetUserId, role);

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

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();
}