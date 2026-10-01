using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Usuarios.Services;

namespace iet_bi_portal_backend.Modules.Usuarios.Controllers;

/// <summary>CU01: consultar mi perfil (cualquier usuario autenticado).</summary>
[Route("api/perfil")]
public class PerfilController(UsuariosService usuarios) : ApiControllerBase
{
    /// <summary>Datos del usuario autenticado. Los roles vienen de la DB (no del token), así que reflejan el estado actual.</summary>
    [Authorize]
    [HttpGet]
    public async Task<IActionResult> ObtenerMiPerfil()
    {
        var perfil = await usuarios.ObtenerAsync(ActorId);
        return perfil is null ? Unauthorized() : Ok(perfil);
    }
}
