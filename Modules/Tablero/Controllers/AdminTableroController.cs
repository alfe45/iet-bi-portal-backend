using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Tablero.Services;

namespace iet_bi_portal_backend.Modules.Tablero.Controllers;

/// <summary>Tablero del Administrador (RP-62; no es un caso de uso): resumen de un curso lectivo en una sola llamada.
/// Exige rol ADMIN.</summary>
[Route("api/admin/tablero")]
public class AdminTableroController(TableroService tablero) : AdminControllerBase
{
    /// <summary>?anio opcional: sin año, el curso lectivo en curso (o el más reciente que ya empezó). 404 (NF004) si el
    /// año no existe. Sin cursos lectivos responde 200 con periodo null.</summary>
    [HttpGet]
    public async Task<IActionResult> Obtener([FromQuery, Range(2000, 2100, ErrorMessage = "El año debe estar entre 2000 y 2100.")] int? anio) =>
        Ok(await tablero.ObtenerAsync(ActorId, anio));
}
