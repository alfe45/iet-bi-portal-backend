using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Services;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = Roles.Admin)]
public class AdminUsersController : ControllerBase
{
    private readonly AuthService _auth;

    public AdminUsersController(AuthService auth) => _auth = auth;

    /// <summary>Otorga un rol adicional. Los roles que ya tenía se conservan.</summary>
    [HttpPost("{id:guid}/roles")]
    public async Task<IActionResult> AssignRole(Guid id, RoleRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        var status = await _auth.AssignRoleAsync(actorId.Value, id, request.Role);
        return status == "OK" ? StatusCode(StatusCodes.Status201Created) : NoContent();
    }

    /// <summary>Quita un rol. Falla (AP003) si sería el último rol que le queda al usuario.</summary>
    [HttpDelete("{id:guid}/roles/{role}")]
    public async Task<IActionResult> RevokeRole(Guid id, string role)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        if (actorId == id)
            return BadRequest(new { codigo = "SELF_ROLE_CHANGE", mensaje = "No puedes modificar tus propios roles." });

        await _auth.RevokeRoleAsync(actorId.Value, id, role.ToUpperInvariant());
        return NoContent();
    }
}

public class RoleRequest
{
    [Required, RegularExpression("^(ADMIN|PROFESOR|GUIA|COORD_MONOGRAFIA|COORD_CAS)$",
        ErrorMessage = "Rol inválido. Valores permitidos: ADMIN, PROFESOR, GUIA, COORD_MONOGRAFIA, COORD_CAS.")]
    public string Role { get; set; } = string.Empty;
}