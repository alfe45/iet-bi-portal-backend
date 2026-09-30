using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Periodos.Models;
using iet_bi_portal_backend.Modules.Periodos.Services;

namespace iet_bi_portal_backend.Modules.Periodos.Controllers;

/// <summary>CU14 a CU17. Se opera siempre por año. Exige rol ADMIN.</summary>
[Route("api/admin/periodos")]
public class AdminPeriodosController(PeriodosService periodos) : AdminControllerBase
{
    /// <summary>CU14: 201 con el año; 409 (PA001) año repetido; 400 (PA002) fechas inválidas.
    /// Se permiten periodos pasados (digitalización).</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarPeriodoRequest request)
    {
        var anio = await periodos.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { anio });
    }

    /// <summary>CU15: listado paginado.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaPaginada consulta) =>
        Ok(await periodos.ListarAsync(consulta.Pagina, consulta.TamanoPagina));

    /// <summary>CU15: detalle por año. 404 (NF004) si no existe.</summary>
    [HttpGet("{anio:int}")]
    public async Task<IActionResult> Obtener(int anio)
    {
        var periodo = await periodos.ObtenerAsync(anio);
        return periodo is null ? this.ApiError("NF004") : Ok(periodo);
    }

    /// <summary>CU16: reemplaza las fechas. 404 (NF004); 400 (PA002/PA005); 409 (PA004) semestre cerrado;
    /// 409 (PA007) reabrir un periodo finalizado.</summary>
    [HttpPut("{anio:int}")]
    public async Task<IActionResult> Actualizar(int anio, ActualizarPeriodoRequest request)
    {
        await periodos.ActualizarAsync(ActorId, anio, request);
        return NoContent();
    }

    /// <summary>CU17: elimina un periodo sin secciones. 404 (NF004); 409 (PA006).</summary>
    [HttpDelete("{anio:int}")]
    public async Task<IActionResult> Eliminar(int anio)
    {
        await periodos.EliminarAsync(ActorId, anio);
        return NoContent();
    }
}
