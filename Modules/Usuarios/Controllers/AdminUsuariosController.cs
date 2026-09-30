using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Usuarios.Models;
using iet_bi_portal_backend.Modules.Usuarios.Services;

namespace iet_bi_portal_backend.Modules.Usuarios.Controllers;

/// <summary>CU02 a CU05. Exige rol ADMIN (AdminControllerBase).</summary>
[Route("api/admin/usuarios")]
public class AdminUsuariosController(UsuariosService usuarios) : AdminControllerBase
{
    /// <summary>CU02: 201 con id y email; 409 (TA001) si el correo ya está en uso.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarUsuarioRequest request)
    {
        var (id, email) = await usuarios.RegistrarAsync(ActorId, request.Email, request.Contrasena);
        return StatusCode(StatusCodes.Status201Created, new { id, email });
    }

    /// <summary>CU03: listado paginado; filtros opcionales ?busqueda= (correo, cédula o nombre del profesor) y ?rol=.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaUsuarios consulta) =>
        Ok(await usuarios.ListarAsync(consulta));

    /// <summary>CU03: detalle. 404 (NF001) si no existe.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Obtener(Guid id)
    {
        var usuario = await usuarios.ObtenerAsync(id);
        return usuario is null ? this.ApiError("NF001") : Ok(usuario);
    }

    /// <summary>CU04: modifica el email (cierra las sesiones del usuario). 409 (TA001) si está en uso.</summary>
    [HttpPatch("{id:guid}/email")]
    public async Task<IActionResult> ActualizarEmail(Guid id, ActualizarEmailRequest request)
    {
        await usuarios.ActualizarEmailAsync(ActorId, id, request.Email);
        return NoContent();
    }

    /// <summary>CU04: resetea la contraseña de otro usuario y cierra todas sus sesiones.</summary>
    [HttpPost("{id:guid}/resetear-contrasena")]
    public async Task<IActionResult> ResetearContrasena(Guid id, ResetearContrasenaRequest request)
    {
        await usuarios.ResetearContrasenaAsync(ActorId, id, request.ContrasenaNueva);
        return NoContent();
    }

    /// <summary>CU04: activa un usuario.</summary>
    [HttpPost("{id:guid}/activar")]
    public async Task<IActionResult> Activar(Guid id)
    {
        await usuarios.CambiarEstadoAsync(ActorId, id, true);
        return NoContent();
    }

    /// <summary>CU04: desactiva un usuario. 409 (AU010) a sí mismo; 409 (AU011) si es el último admin activo.</summary>
    [HttpPost("{id:guid}/desactivar")]
    public async Task<IActionResult> Desactivar(Guid id)
    {
        await usuarios.CambiarEstadoAsync(ActorId, id, false);
        return NoContent();
    }

    /// <summary>CU04: otorga un rol. 201 si se asignó; 204 si ya lo tenía.</summary>
    [HttpPost("{id:guid}/roles")]
    public async Task<IActionResult> AsignarRol(Guid id, RolRequest request)
    {
        var asignado = await usuarios.AsignarRolAsync(ActorId, id, request.Rol);
        return asignado ? StatusCode(StatusCodes.Status201Created) : NoContent();
    }

    /// <summary>CU04: quita un rol. 409 (AU005) si es el único; 409 (AU003/AU004) reglas de ADMIN;
    /// 409 (AU016) GUIA de un guía con sección en periodo no finalizado.</summary>
    [HttpDelete("{id:guid}/roles/{rol}")]
    public async Task<IActionResult> RevocarRol(Guid id, [RolValido] string rol)
    {
        await usuarios.RevocarRolAsync(ActorId, id, rol);
        return NoContent();
    }

    /// <summary>CU05: elimina el usuario. 409 (AU012) a sí mismo; 409 (AU013) último admin; 409 (PR003) si tiene perfil de profesor.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Eliminar(Guid id)
    {
        await usuarios.EliminarAsync(ActorId, id);
        return NoContent();
    }
}
