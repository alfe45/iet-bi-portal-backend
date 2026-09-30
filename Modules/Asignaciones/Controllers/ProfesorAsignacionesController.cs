using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Asignaciones.Services;

namespace iet_bi_portal_backend.Modules.Asignaciones.Controllers;

/// <summary>Profesor Regular CU03: secciones y asignaturas que imparte el profesor autenticado.</summary>
[Route("api/profesor/asignaciones")]
[Authorize(Roles = Roles.ProfesorRegular)]
public class ProfesorAsignacionesController(AsignacionesService asignaciones) : ApiControllerBase
{
    /// <summary>Mis asignaciones del año indicado, o del periodo en curso si no se indica (404 NF005 si no hay).</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] int? anio) =>
        Ok(await asignaciones.ListarMisAsignacionesAsync(ActorId, anio));
}
