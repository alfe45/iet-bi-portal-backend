using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Asignaturas.Models;
using iet_bi_portal_backend.Modules.Asignaturas.Services;
using iet_bi_portal_backend.Modules.Errors;

namespace iet_bi_portal_backend.Modules.Asignaturas.Controllers;

/// <summary>CU29 a CU32. Se opera siempre por código. Exige rol ADMIN.</summary>
[Route("api/admin/asignaturas")]
public class AdminAsignaturasController(AsignaturasService asignaturas) : AdminControllerBase
{
    /// <summary>CU29: 201 con el código; 409 (AS001/AS002) código o nombre repetido; 400 (AS003/AS004).</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarAsignaturaRequest request)
    {
        var codigo = await asignaturas.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { codigo });
    }

    /// <summary>CU30: listado paginado; filtros opcionales ?tipo=MEP&amp;nivel=11.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaAsignaturas consulta) =>
        Ok(await asignaturas.ListarAsync(consulta));

    /// <summary>CU30: detalle por código. 404 (NF007) si no existe.</summary>
    [HttpGet("{codigo}")]
    public async Task<IActionResult> Obtener(string codigo)
    {
        var asignatura = await asignaturas.ObtenerAsync(codigo);
        return asignatura is null ? this.ApiError("NF007") : Ok(asignatura);
    }

    /// <summary>CU31: modifica la asignatura (reemplazo completo, menos el código). 404 (NF007); 409 (AS002); 400 (AS003).</summary>
    [HttpPut("{codigo}")]
    public async Task<IActionResult> Actualizar(string codigo, ActualizarAsignaturaRequest request)
    {
        await asignaturas.ActualizarAsync(ActorId, codigo, request);
        return NoContent();
    }

    /// <summary>CU32: elimina la asignatura. 404 (NF007); 409 (23001) si tiene asignaciones.</summary>
    [HttpDelete("{codigo}")]
    public async Task<IActionResult> Eliminar(string codigo)
    {
        await asignaturas.EliminarAsync(ActorId, codigo);
        return NoContent();
    }
}
