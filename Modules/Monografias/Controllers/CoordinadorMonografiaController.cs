using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Monografias.Models;
using iet_bi_portal_backend.Modules.Monografias.Services;

namespace iet_bi_portal_backend.Modules.Monografias.Controllers;

/// <summary>Coordinador de Monografía CU01 a CU05 (estado, seguimiento y reportes al guía). Solo el coordinador de la
/// monografía la opera (403 AD006). Las monografías se identifican por la cédula del estudiante; los seguimientos, por id.</summary>
[Route("api/profesor/monografias")]
[Authorize(Roles = Roles.CoordMonografia)]
public class CoordinadorMonografiaController(MonografiasService monografias) : ApiControllerBase
{
    /// <summary>CU01: mis monografías; filtros opcionales ?anioInicio=&amp;estado=.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaMisMonografias consulta) =>
        Ok(await monografias.ListarMiasAsync(ActorId, consulta));

    /// <summary>CU01: monografía con su seguimiento y reportes. 404 (NF003/NF013); 403 (AD006).</summary>
    [HttpGet("{cedula}")]
    public async Task<IActionResult> Obtener(string cedula) => Ok(await monografias.ObtenerMiaAsync(ActorId, cedula));

    /// <summary>CU02: cambia el estado (RN-79). 404 (NF003/NF013); 403 (AD006).</summary>
    [HttpPut("{cedula}/estado")]
    public async Task<IActionResult> CambiarEstado(string cedula, CambiarEstadoMonografiaRequest request)
    {
        await monografias.CambiarEstadoAsync(ActorId, cedula, request);
        return NoContent();
    }

    /// <summary>CU03: 201 con el id. 404 (NF003/NF013); 403 (AD006); 400 (MO006) fecha futura o anterior a la monografía.</summary>
    [HttpPost("{cedula}/seguimientos")]
    public async Task<IActionResult> RegistrarSeguimiento(string cedula, RegistrarSeguimientoRequest request)
    {
        var idSeguimiento = await monografias.RegistrarSeguimientoAsync(ActorId, cedula, request);
        return StatusCode(StatusCodes.Status201Created, new { idSeguimiento });
    }

    /// <summary>CU04: 404 (NF014); 403 (AD006); 400 (MO006).</summary>
    [HttpPut("seguimientos/{idSeguimiento:long}")]
    public async Task<IActionResult> ModificarSeguimiento(long idSeguimiento, ModificarSeguimientoRequest request)
    {
        await monografias.ModificarSeguimientoAsync(ActorId, idSeguimiento, request);
        return NoContent();
    }

    /// <summary>CU04: 404 (NF014); 403 (AD006).</summary>
    [HttpDelete("seguimientos/{idSeguimiento:long}")]
    public async Task<IActionResult> EliminarSeguimiento(long idSeguimiento)
    {
        await monografias.EliminarSeguimientoAsync(ActorId, idSeguimiento);
        return NoContent();
    }

    /// <summary>CU05: envía (o corrige) el reporte del semestre al guía (RN-81). 404 (NF003/NF013/NF004/NF009); 403 (AD006);
    /// 409 (EV002/EV003) fuera del plazo del semestre.</summary>
    [HttpPut("{cedula}/reportes/{anio:int}/{semestre}")]
    public async Task<IActionResult> EnviarReporte(string cedula, int anio, string semestre, ReporteMonografiaRequest request)
    {
        await monografias.EnviarReporteAsync(ActorId, cedula, anio, semestre, request);
        return NoContent();
    }

    /// <summary>CU05: retira el reporte del semestre (corrección). 404 (NF003/NF013/NF004/NF017); 403 (AD006); 409 (EV002/EV003).</summary>
    [HttpDelete("{cedula}/reportes/{anio:int}/{semestre}")]
    public async Task<IActionResult> EliminarReporte(string cedula, int anio, string semestre)
    {
        await monografias.EliminarReporteAsync(ActorId, cedula, anio, semestre);
        return NoContent();
    }
}
