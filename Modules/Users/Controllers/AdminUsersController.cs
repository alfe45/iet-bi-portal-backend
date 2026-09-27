using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Users.Models;
using iet_bi_portal_backend.Modules.Users.Services;

namespace iet_bi_portal_backend.Modules.Users.Controllers;

[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = Roles.Admin)]
public class AdminUsersController : ControllerBase
{
    private readonly UsersService _users;

    public AdminUsersController(UsersService users) => _users = users;

    /// <summary>CU02: registra un usuario nuevo con rol PROFESOR_REGULAR.
    /// Devuelve 201 Created con su id y email, o 409 Conflict (TA001) si el correo ya está en uso.</summary>
    [HttpPost]
    public async Task<IActionResult> Register(RegisterRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        var id = await _users.RegisterUserAsync(actorId.Value, request.Email, request.Password);
        return StatusCode(StatusCodes.Status201Created, new { id, email = request.Email.Trim().ToLowerInvariant() });
    }

    /// <summary>CU03: lista usuarios paginados, sin filtros (los aplica el frontend).</summary>
    [HttpGet]
    public async Task<IActionResult> GetUsers([FromQuery] ListUsersQuery query)
    {
        var result = await _users.GetUsersAsync(query.Page, query.PageSize);
        return Ok(result);
    }

    /// <summary>CU03: detalle de un usuario puntual. Devuelve 404 (NF001) si no existe.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetUser(Guid id)
    {
        var user = await _users.GetUserByIdAsync(id);
        return user is null ? this.ApiError("NF001") : Ok(user);
    }

    /// <summary>CU04: modifica el email de un usuario. Invalida sus sesiones (el JWT lleva el
    /// email como claim). Devuelve 409 (TA001) si el correo ya está en uso.</summary>
    [HttpPatch("{id:guid}/email")]
    public async Task<IActionResult> UpdateEmail(Guid id, UpdateEmailRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.UpdateEmailAsync(actorId.Value, id, request.Email);
        return NoContent();
    }

    /// <summary>CU04: resetea la contraseña de otro usuario. No requiere la contraseña actual:
    /// la autoridad es ser ADMIN. Cierra todas las sesiones del usuario objetivo.</summary>
    [HttpPost("{id:guid}/reset-password")]
    public async Task<IActionResult> ResetPassword(Guid id, ResetPasswordRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.ResetPasswordAsync(actorId.Value, id, request.NewPassword);
        return NoContent();
    }

    /// <summary>CU05: activa un usuario previamente desactivado.</summary>
    [HttpPost("{id:guid}/activate")]
    public async Task<IActionResult> Activate(Guid id)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.SetActiveAsync(actorId.Value, id, true);
        return NoContent();
    }

    /// <summary>CU05: desactiva un usuario. Falla (AU010) si un admin intenta desactivarse a
    /// sí mismo, o (AU011) si sería el último admin activo del sistema. Cierra todas sus
    /// sesiones e invalida sus tokens ya emitidos.</summary>
    [HttpPost("{id:guid}/deactivate")]
    public async Task<IActionResult> Deactivate(Guid id)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.SetActiveAsync(actorId.Value, id, false);
        return NoContent();
    }

    /// <summary>CU06: otorga un rol adicional. Los roles que ya tenía se conservan.</summary>
    [HttpPost("{id:guid}/roles")]
    public async Task<IActionResult> AssignRole(Guid id, RoleRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        var status = await _users.AssignRoleAsync(actorId.Value, id, request.Role);
        return status == "OK" ? StatusCode(StatusCodes.Status201Created) : NoContent();
    }

    /// <summary>CU06: quita un rol. Falla (AU005) si sería el último rol que le queda al usuario,
    /// o (AU003) si un ADMIN intenta quitarse a sí mismo el rol ADMIN.</summary>
    [HttpDelete("{id:guid}/roles/{role}")]
    public async Task<IActionResult> RevokeRole(Guid id, string role)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.RevokeRoleAsync(actorId.Value, id, role.ToUpperInvariant());
        return NoContent();
    }

    /// <summary>CU07: elimina físicamente un usuario. Falla (AU012) si un admin intenta
    /// eliminarse a sí mismo, o (AU013) si sería el último admin activo del sistema.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.DeleteUserAsync(actorId.Value, id);
        return NoContent();
    }
}