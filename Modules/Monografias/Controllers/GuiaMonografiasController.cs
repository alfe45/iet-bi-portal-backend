using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Monografias.Models;
using iet_bi_portal_backend.Modules.Monografias.Services;

namespace iet_bi_portal_backend.Modules.Monografias.Controllers;

/// <summary>Guía CU06 (reportes de monografía) y CU07 (verificar las monografías) de su sección guía. 403 (AD005) si no es
/// el guía de la sección.</summary>
[Route("api/profesor/guia/monografias")]
[Authorize(Roles = Roles.Guia)]
public class GuiaMonografiasController(MonografiasService monografias) : ApiControllerBase
{
    /// <summary>CU07: estado y seguimiento de las monografías de los estudiantes de la sección (?anio&amp;nivel&amp;numero). 404 (NF006).</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaSeccionGuia consulta) =>
        Ok(await monografias.ListarSeccionGuiaAsync(ActorId, consulta));

    /// <summary>CU06: reporte del semestre de cada monografía (?anio&amp;nivel&amp;numero&amp;semestre); observaciones null = sin reporte. 404 (NF006).</summary>
    [HttpGet("reportes")]
    public async Task<IActionResult> Reportes([FromQuery] ConsultaReportesGuia consulta) =>
        Ok(await monografias.ReportesSeccionGuiaAsync(ActorId, consulta));

    /// <summary>Permite al guía reactivar la edición de un reporte confirmado. 404 (NF004/NF013/NF017); 403 (AD005).</summary>
    [HttpPut("reportes/{anio:int}/{nivel:int}/{numero:int}/{cedula}/permitir-cambios/{semestre}")]
    public async Task<IActionResult> PermitirCambios(int anio, int nivel, int numero, string cedula, string semestre)
    {
        await monografias.PermitirCambiosReporteAsync(ActorId, anio, nivel, numero, cedula, semestre);
        return NoContent();
    }
}
