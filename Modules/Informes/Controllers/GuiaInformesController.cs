using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Informes.Models;
using iet_bi_portal_backend.Modules.Informes.Services;

namespace iet_bi_portal_backend.Modules.Informes.Controllers;

/// <summary>Guía CU08 (informe de notas de un estudiante) y CU09 (de toda la sección): reporte de bandas del semestre
/// (RN-85). El backend devuelve los datos y el front arma el PDF. 403 (AD005) si no es el guía de la sección.</summary>
[Route("api/profesor/guia/reporte-bandas")]
[Authorize(Roles = Roles.Guia)]
public class GuiaInformesController(InformesService informes) : ApiControllerBase
{
    /// <summary>CU09: ?anio&amp;nivel&amp;numero&amp;semestre. 404 (NF006).</summary>
    [HttpGet]
    public async Task<IActionResult> Seccion([FromQuery] ConsultaReporteBandas consulta) =>
        Ok(await informes.ReportesSeccionAsync(ActorId, consulta));

    /// <summary>CU08: 404 (NF006); 404 (NF009) si el estudiante no se califica en la sección ese semestre.</summary>
    [HttpGet("{cedula}")]
    public async Task<IActionResult> Estudiante(string cedula, [FromQuery] ConsultaReporteBandas consulta) =>
        Ok(await informes.ReporteEstudianteAsync(ActorId, consulta, cedula));
}
