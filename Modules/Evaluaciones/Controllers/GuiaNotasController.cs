using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Evaluaciones.Models;
using iet_bi_portal_backend.Modules.Evaluaciones.Services;

namespace iet_bi_portal_backend.Modules.Evaluaciones.Controllers;

/// <summary>Guía CU03 / CU04 (unificados): notas de una sección por estudiante y asignación (RN-77). Cualquier guía consulta
/// cualquier sección; la nota solo aparece si el profesor ya la envió.</summary>
[Route("api/profesor/guia/notas")]
[Authorize(Roles = Roles.Guia)]
public class GuiaNotasController(EvaluacionesService evaluaciones) : ApiControllerBase
{
    /// <summary>?anio&amp;nivel&amp;numero&amp;semestre. 404 (NF006).</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaNotasSeccion consulta) =>
        Ok(await evaluaciones.NotasSeccionAsync(consulta));
}
