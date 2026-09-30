using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Profesores.Models;
using iet_bi_portal_backend.Modules.Profesores.Services;

namespace iet_bi_portal_backend.Modules.Profesores.Controllers;

/// <summary>CU08 a CU11. Se opera siempre por cédula (RP-07). Exige rol ADMIN.</summary>
[Route("api/admin/profesores")]
public class AdminProfesoresController(ProfesoresService profesores) : AdminControllerBase
{
    /// <summary>CU08: 201 con la cédula; 404 (NF001) usuario inexistente; 409 (PR001) el usuario ya tiene perfil; 409 (PR002) cédula en uso.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarProfesorRequest request)
    {
        var cedula = await profesores.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { cedula });
    }

    /// <summary>CU09: listado paginado.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaPaginada consulta) =>
        Ok(await profesores.ListarAsync(consulta.Pagina, consulta.TamanoPagina));

    /// <summary>CU09: detalle por cédula. 404 (NF002) si no existe.</summary>
    [HttpGet("{cedula}")]
    public async Task<IActionResult> Obtener(string cedula)
    {
        var profesor = await profesores.ObtenerAsync(cedula);
        return profesor is null ? this.ApiError("NF002") : Ok(profesor);
    }

    /// <summary>CU10: modifica un profesor (reemplazo completo de los campos editables). 404 (NF002) si no existe.</summary>
    [HttpPut("{cedula}")]
    public async Task<IActionResult> Actualizar(string cedula, ActualizarProfesorRequest request)
    {
        await profesores.ActualizarAsync(ActorId, cedula, request);
        return NoContent();
    }

    /// <summary>CU11: elimina el perfil de profesor (el usuario se conserva). 404 (NF002) si no existe.</summary>
    [HttpDelete("{cedula}")]
    public async Task<IActionResult> Eliminar(string cedula)
    {
        await profesores.EliminarAsync(ActorId, cedula);
        return NoContent();
    }
}
