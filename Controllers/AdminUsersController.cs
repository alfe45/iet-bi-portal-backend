using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Auth.Models;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = Roles.Admin)]
public class AdminUsersController : ControllerBase
{
    private readonly AuthService _auth;

    public AdminUsersController(AuthService auth) => _auth = auth;

    /// <summary>Otorga un rol adicional a un usuario (los roles que ya tenía se conservan).</summary>
    [HttpPost("{id:guid}/roles")]
    public async Task<IActionResult> AssignRole(Guid id, RoleRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        var result = await _auth.AssignRoleAsync(actorId.Value, id, request.Role);
        return MapResult(result);
    }

    /// <summary>Quita un rol de un usuario. Falla si sería el último rol que le queda.</summary>
    [HttpDelete("{id:guid}/roles/{role}")]
    public async Task<IActionResult> RevokeRole(Guid id, string role)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        if (actorId == id)
            return BadRequest(new { error = "No puedes modificar tus propios roles." });

        var result = await _auth.RevokeRoleAsync(actorId.Value, id, role.ToUpperInvariant());
        return MapResult(result);
    }

    private IActionResult MapResult(ChangeRoleResult result) => result switch
    {
        ChangeRoleResult.Ok => NoContent(),
        ChangeRoleResult.NoChange => NoContent(),
        ChangeRoleResult.Forbidden => Forbid(),
        ChangeRoleResult.NotFound => NotFound(new { error = "El usuario no existe." }),
        ChangeRoleResult.InvalidRole => BadRequest(new { error = "Rol inválido. Valores permitidos: ADMIN, PROFESOR, GUIA, COORD_MONOGRAFIA, COORD_CAS." }),
        ChangeRoleResult.CannotRemoveLastRole => BadRequest(new { error = "No se puede quitar el rol del usuario." }),
        _ => StatusCode(StatusCodes.Status500InternalServerError)
    };
}

public record RoleRequest(
    [Required]
    [RegularExpression(
        "^(ADMIN|PROFESOR|GUIA|COORD_MONOGRAFIA|COORD_CAS)$",
        ErrorMessage = "Rol inválido. Valores permitidos: ADMIN, PROFESOR, GUIA, COORD_MONOGRAFIA, COORD_CAS."
    )]
    string Role
);