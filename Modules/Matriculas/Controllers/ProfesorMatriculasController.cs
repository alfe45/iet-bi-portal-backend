using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Matriculas.Services;

namespace iet_bi_portal_backend.Modules.Matriculas.Controllers;

/// <summary>Profesor Regular CU04 / Guía CU02: estudiantes de una sección. Solo si el profesor imparte en
/// la sección o es su guía (403 AD003 si no).</summary>
[Route("api/profesor/secciones")]
[Authorize(Roles = Roles.ProfesorRegular + "," + Roles.Guia)]
public class ProfesorMatriculasController(MatriculasService matriculas) : ApiControllerBase
{
    [HttpGet("{anio:int}/{nivel:int}/{numero:int}/estudiantes")]
    public async Task<IActionResult> ListarEstudiantes(int anio, int nivel, int numero) =>
        Ok(await matriculas.ListarEstudiantesSeccionAsync(ActorId, anio, nivel, numero));
}
