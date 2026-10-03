using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Cas.Models;
using iet_bi_portal_backend.Modules.Cas.Services;

namespace iet_bi_portal_backend.Modules.Cas.Controllers;

/// <summary>Coordinador de CAS CU01 (progreso CAS general) y CU02 (generar el reporte CAS) (RN-84). Ve todas las secciones;
/// la nota CAS solo aparece si el profesor ya la envió. El front arma el PDF con el formato del Instituto.</summary>
[Route("api/profesor/coordinacion-cas")]
[Authorize(Roles = Roles.CoordCas)]
public class CoordinadorCasController(CasService cas) : ApiControllerBase
{
    /// <summary>CU01: ?anio&amp;semestre y opcionales &amp;nivel&amp;numero.</summary>
    [HttpGet("progreso")]
    public async Task<IActionResult> Progreso([FromQuery] ConsultaProgresoGeneral consulta) =>
        Ok(await cas.ProgresoGeneralAsync(consulta));

    /// <summary>CU02: informes CAS del estudiante en el semestre (uno por profesor CAS de su sección). 404 (NF004/NF003/NF009/NF015).</summary>
    [HttpGet("informes/{anio:int}/{semestre}/{cedula}")]
    public async Task<IActionResult> Informes(int anio, string semestre, string cedula) =>
        Ok(await cas.InformesEstudianteAsync(anio, semestre, cedula));
}
