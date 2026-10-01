using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Ausentismo.Models;
using iet_bi_portal_backend.Modules.Ausentismo.Services;

namespace iet_bi_portal_backend.Modules.Ausentismo.Controllers;

/// <summary>Guía CU05: ausentismo de la sección guía por estudiante y asignatura (RN-71).</summary>
[Route("api/profesor/guia/ausentismo")]
[Authorize(Roles = Roles.Guia)]
public class GuiaAusentismoController(AusentismoService ausentismo) : ApiControllerBase
{
    /// <summary>?anio=&amp;nivel=&amp;numero= y opcional ?semestre=. 404 (NF006); 403 (AD005) si no es el guía de la sección.</summary>
    [HttpGet]
    public async Task<IActionResult> Resumen([FromQuery] ConsultaAusentismoGuia consulta) =>
        Ok(await ausentismo.ResumenGuiaAsync(ActorId, consulta));
}
