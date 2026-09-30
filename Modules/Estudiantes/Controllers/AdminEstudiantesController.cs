using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Estudiantes.Models;
using iet_bi_portal_backend.Modules.Estudiantes.Services;

namespace iet_bi_portal_backend.Modules.Estudiantes.Controllers;

/// <summary>CU12 a CU15. Se opera siempre por cédula (RP-07). Exige rol ADMIN.</summary>
[Route("api/admin/estudiantes")]
public class AdminEstudiantesController(EstudiantesService estudiantes) : AdminControllerBase
{
    /// <summary>CU12: 201 con la cédula; 409 (ES001) cédula en uso; 409 (ES002) correo en uso; 400 (ES003) edad fuera de 16 a 19 años.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarEstudianteRequest request)
    {
        var cedula = await estudiantes.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { cedula });
    }

    /// <summary>CU13: listado paginado.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaPaginada consulta) =>
        Ok(await estudiantes.ListarAsync(consulta.Pagina, consulta.TamanoPagina));

    /// <summary>CU13: detalle por cédula. 404 (NF003) si no existe.</summary>
    [HttpGet("{cedula}")]
    public async Task<IActionResult> Obtener(string cedula)
    {
        var estudiante = await estudiantes.ObtenerAsync(cedula);
        return estudiante is null ? this.ApiError("NF003") : Ok(estudiante);
    }

    /// <summary>CU14: modifica un estudiante (reemplazo completo). 404 (NF003); 409 (ES002); 400 (ES003) si cambia la fecha y queda fuera de rango.</summary>
    [HttpPut("{cedula}")]
    public async Task<IActionResult> Actualizar(string cedula, ActualizarEstudianteRequest request)
    {
        await estudiantes.ActualizarAsync(ActorId, cedula, request);
        return NoContent();
    }

    /// <summary>CU15: elimina un estudiante. 404 (NF003) si no existe.</summary>
    [HttpDelete("{cedula}")]
    public async Task<IActionResult> Eliminar(string cedula)
    {
        await estudiantes.EliminarAsync(ActorId, cedula);
        return NoContent();
    }
}
