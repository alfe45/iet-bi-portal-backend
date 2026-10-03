using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Asignaturas.Models;
using iet_bi_portal_backend.Modules.Asignaturas.Services;
using iet_bi_portal_backend.Modules.Errors;

namespace iet_bi_portal_backend.Modules.Asignaturas.Controllers;

/// <summary>Administrador CU26 a CU29 (registrar, consultar, modificar y eliminar asignaturas). Se opera siempre por código. Exige rol ADMIN.</summary>
[Route("api/admin/asignaturas")]
public class AdminAsignaturasController(AsignaturasService asignaturas) : AdminControllerBase
{
    /// <summary>CU26: 201 con el código; 409 (AS001/AS002) código o nombre repetido; 400 (AS003/AS004); 400 (AS008) CAS no TRONCAL.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarAsignaturaRequest request)
    {
        var codigo = await asignaturas.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { codigo });
    }

    /// <summary>CU27: listado paginado; filtros opcionales ?tipo=MEP&amp;nivel=11.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaAsignaturas consulta) =>
        Ok(await asignaturas.ListarAsync(ActorId, consulta));

    /// <summary>CU27: detalle por código. 404 (NF007) si no existe.</summary>
    [HttpGet("{codigo}")]
    public async Task<IActionResult> Obtener(string codigo)
    {
        var asignatura = await asignaturas.ObtenerAsync(ActorId, codigo);
        return asignatura is null ? this.ApiError("NF007") : Ok(asignatura);
    }

    /// <summary>CU28: modifica la asignatura (reemplazo completo, menos el código). 404 (NF007); 409 (AS002); 400 (AS003);
    /// 409 (AS006) tipo con notas o monografías; 409 (AS007) nivel con asignaciones; 400 (AS008) CAS no TRONCAL.</summary>
    [HttpPut("{codigo}")]
    public async Task<IActionResult> Actualizar(string codigo, ActualizarAsignaturaRequest request)
    {
        await asignaturas.ActualizarAsync(ActorId, codigo, request);
        return NoContent();
    }

    /// <summary>CU29: elimina la asignatura. 404 (NF007); 409 (23001) si tiene asignaciones.</summary>
    [HttpDelete("{codigo}")]
    public async Task<IActionResult> Eliminar(string codigo)
    {
        await asignaturas.EliminarAsync(ActorId, codigo);
        return NoContent();
    }
}
