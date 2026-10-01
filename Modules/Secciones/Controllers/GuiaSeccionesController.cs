using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Secciones.Services;

namespace iet_bi_portal_backend.Modules.Secciones.Controllers;

/// <summary>Guía CU01: la sección que el profesor autenticado tiene asignada como guía.</summary>
[Route("api/profesor/guia/secciones")]
[Authorize(Roles = Roles.Guia)]
public class GuiaSeccionesController(SeccionesService secciones) : ApiControllerBase
{
    /// <summary>Mis secciones guía del año indicado, o del periodo en curso si no se indica (404 NF005 si no hay).
    /// Sus estudiantes: GET /api/profesor/secciones/{anio}/{nivel}/{numero}/estudiantes.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] int? anio) =>
        Ok(await secciones.ListarMisSeccionesGuiaAsync(ActorId, anio));
}
