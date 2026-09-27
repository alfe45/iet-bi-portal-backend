using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Users.Data;
using iet_bi_portal_backend.Modules.Users.Models;
using iet_bi_portal_backend.Security;

namespace iet_bi_portal_backend.Modules.Users.Services;

public class UsersService
{
    private readonly UsersRepository _repo;
    private readonly ILogsService _logs;
    private readonly IPasswordService _passwords;

    public UsersService(UsersRepository repo, ILogsService logs, IPasswordService passwords)
    {
        _repo = repo;
        _logs = logs;
        _passwords = passwords;
    }

    /// <summary>CU02: registra un usuario nuevo con rol PROFESOR_REGULAR. Requiere que el
    /// actor sea ADMIN activo (lo valida la DB, AU009/TA001). No emite sesión: el admin no
    /// recibe tokens del usuario creado.</summary>
    public async Task<Guid> RegisterUserAsync(Guid actorUserId, string email, string password)
    {
        email = NormalizeEmail(email);
        var userId = await _repo.RegisterUserAsync(actorUserId, email, _passwords.Hash(password));

        await _logs.RegisterLogAsync(actorUserId, "CREATE_USER", "api.usuarios", userId.ToString(),
            newData: new { email, roles = new[] { Roles.ProfesorRegular } });

        return userId;
    }

    /// <summary>CU03: lista usuarios paginados, sin filtros (los aplica el frontend).</summary>
    public async Task<PagedResult<UserAdminResponse>> GetUsersAsync(int page, int pageSize)
    {
        var (items, total) = await _repo.GetUsersPagedAsync(page, pageSize);
        return new PagedResult<UserAdminResponse>(items.Select(MapToResponse).ToList(), page, pageSize, total);
    }

    /// <summary>CU03: detalle de un usuario puntual, o null si no existe.</summary>
    public async Task<UserAdminResponse?> GetUserByIdAsync(Guid id)
    {
        var record = await _repo.GetUserByIdAsync(id);
        return record is null ? null : MapToResponse(record);
    }

    /// <summary>CU04: modifica el email de un usuario. Invalida sus sesiones y tokens
    /// (el JWT lleva el email como claim).</summary>
    public async Task<string> UpdateEmailAsync(Guid actorUserId, Guid targetUserId, string newEmail)
    {
        newEmail = NormalizeEmail(newEmail);
        var status = await _repo.UpdateEmailAsync(actorUserId, targetUserId, newEmail);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "UPDATE_USER_EMAIL", "api.usuarios", targetUserId.ToString(),
                newData: new { email = newEmail });

        return status;
    }

    /// <summary>CU04: resetea la contraseña de otro usuario (acción de administrador, no
    /// requiere la contraseña actual). Nunca se loguea el hash ni la contraseña en sí.</summary>
    public async Task ResetPasswordAsync(Guid actorUserId, Guid targetUserId, string newPassword)
    {
        await _repo.ResetPasswordAsync(actorUserId, targetUserId, _passwords.Hash(newPassword));
        await _logs.RegisterLogAsync(actorUserId, "RESET_PASSWORD", "api.usuarios", targetUserId.ToString());
    }

    /// <summary>CU05: activa o desactiva un usuario. No permite auto-desactivación ni dejar
    /// el sistema sin ningún admin activo (lo valida la DB, AU010/AU011).</summary>
    public async Task<string> SetActiveAsync(Guid actorUserId, Guid targetUserId, bool activo)
    {
        var status = await _repo.SetActiveAsync(actorUserId, targetUserId, activo);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, activo ? "ACTIVATE_USER" : "DEACTIVATE_USER",
                "api.usuarios", targetUserId.ToString());

        return status;
    }

    /// <summary>CU06: otorga un rol. Requiere que el actor sea ADMIN activo (lo valida la DB, AU002/NF001).</summary>
    public async Task<string> AssignRoleAsync(Guid actorUserId, Guid targetUserId, string role)
    {
        var status = await _repo.AssignRoleAsync(actorUserId, targetUserId, role);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "ASSIGN_ROLE", "api.usuario_roles", targetUserId.ToString(),
                newData: new { rol = role });

        return status;
    }

    /// <summary>CU06: quita un rol. No permite dejar al usuario sin roles (AU002/NF001/AU003/AU004/AU005).</summary>
    public async Task<string> RevokeRoleAsync(Guid actorUserId, Guid targetUserId, string role)
    {
        var status = await _repo.RevokeRoleAsync(actorUserId, targetUserId, role);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "REVOKE_ROLE", "api.usuario_roles", targetUserId.ToString(),
                previousData: new { rol = role });

        return status;
    }

    /// <summary>CU07: elimina físicamente un usuario. No permite auto-eliminación ni dejar el
    /// sistema sin ningún admin activo (lo valida la DB, AU012/AU013). Loguea el email y los
    /// roles que tenía justo antes de borrarlo, porque después del DELETE ya no hay nada
    /// que consultar.</summary>
    public async Task DeleteUserAsync(Guid actorUserId, Guid targetUserId)
    {
        var (email, roles) = await _repo.DeleteUserAsync(actorUserId, targetUserId);

        await _logs.RegisterLogAsync(actorUserId, "DELETE_USER", "api.usuarios", targetUserId.ToString(),
            previousData: new { email, roles });
    }

    private static UserAdminResponse MapToResponse(UserAdminRecord r) => new(
        r.Id, r.Email, r.Activo, r.BloqueadoHasta, r.UltimoLogin, r.CreadoEn, r.Roles, r.CantidadSesiones);

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();
}