using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Periodos.Services;

namespace iet_bi_portal_backend.Modules.Periodos.Controllers;

/// <summary>Consulta del periodo actual para cualquier usuario autenticado (pantalla principal, validaciones del front).</summary>
[Route("api/periodos")]
public class PeriodosController(PeriodosService periodos) : ApiControllerBase
{
    /// <summary>Año y semestre en curso. 404 (NF005) si hoy no cae en ningún periodo (vacaciones de fin de año).
    /// semestreActual es null durante el receso entre semestres.</summary>
    [Authorize]
    [HttpGet("actual")]
    public async Task<IActionResult> ObtenerActual()
    {
        var periodo = await periodos.ObtenerActualAsync();
        return periodo is null ? this.ApiError("NF005") : Ok(periodo);
    }
}
