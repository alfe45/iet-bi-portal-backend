using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Ausentismo.Models;
using iet_bi_portal_backend.Modules.Ausentismo.Services;

namespace iet_bi_portal_backend.Modules.Ausentismo.Controllers;

/// <summary>Profesor Regular CU10 a CU12 (registrar, modificar y consultar ausentismo). Las lecciones se identifican
/// por id (RP-53) y solo las opera el profesor de la asignación (403 AD004). Cuando el semestre de la lección
/// terminó, queda cerrada (409 PA004).</summary>
[Route("api/profesor")]
[Authorize(Roles = Roles.ProfesorRegular)]
public class ProfesorAusentismoController(AusentismoService ausentismo) : ApiControllerBase
{
    /// <summary>CU10: 201 con el id. 404 (NF006/NF007); 403 (AD004); 400 (LE001) fecha futura o fuera de los semestres;
    /// 409 (LE002) fecha y hora repetidas; 400 (LE003) ausente o tardío no matriculado a esa fecha; 400 (LE004) un
    /// estudiante ausente y tardío a la vez; 409 (PA004).</summary>
    [HttpPost("lecciones")]
    public async Task<IActionResult> RegistrarLeccion(RegistrarLeccionRequest request)
    {
        var idLeccion = await ausentismo.RegistrarLeccionAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { idLeccion });
    }

    /// <summary>CU12: lecciones de mi asignación, paginadas; filtro opcional ?semestre=I_SEMESTRE.</summary>
    [HttpGet("lecciones")]
    public async Task<IActionResult> ListarLecciones([FromQuery] ConsultaLecciones consulta) =>
        Ok(await ausentismo.ListarLeccionesAsync(ActorId, consulta));

    /// <summary>CU12: lección con sus ausentes. 404 (NF010); 403 (AD004).</summary>
    [HttpGet("lecciones/{idLeccion:long}")]
    public async Task<IActionResult> ObtenerLeccion(long idLeccion) =>
        Ok(await ausentismo.ObtenerLeccionAsync(ActorId, idLeccion));

    /// <summary>CU11: corrige fecha, hora y tema y reemplaza ausentes y tardíos (conserva las justificaciones de quien
    /// sigue ausente). 404 (NF010); 403 (AD004); 400 (LE001/LE003/LE004); 409 (LE002/PA004).</summary>
    [HttpPut("lecciones/{idLeccion:long}")]
    public async Task<IActionResult> ModificarLeccion(long idLeccion, ModificarLeccionRequest request)
    {
        await ausentismo.ModificarLeccionAsync(ActorId, idLeccion, request);
        return NoContent();
    }

    /// <summary>CU11: elimina la lección y sus ausencias. 404 (NF010); 403 (AD004); 409 (PA004).</summary>
    [HttpDelete("lecciones/{idLeccion:long}")]
    public async Task<IActionResult> EliminarLeccion(long idLeccion)
    {
        await ausentismo.EliminarLeccionAsync(ActorId, idLeccion);
        return NoContent();
    }

    /// <summary>CU11: justifica la ausencia del estudiante (RN-69); una llegada tardía no se justifica (NF011).
    /// 404 (NF010/NF003/NF011); 403 (AD004); 409 (PA004).</summary>
    [HttpPut("lecciones/{idLeccion:long}/ausencias/{cedula}/justificacion")]
    public async Task<IActionResult> JustificarAusencia(long idLeccion, string cedula, JustificarAusenciaRequest request)
    {
        await ausentismo.JustificarAusenciaAsync(ActorId, idLeccion, cedula, request);
        return NoContent();
    }

    /// <summary>CU11: anula la justificación. 204 aunque no tuviera; 404 (NF010/NF003/NF011); 403 (AD004); 409 (PA004).</summary>
    [HttpDelete("lecciones/{idLeccion:long}/ausencias/{cedula}/justificacion")]
    public async Task<IActionResult> AnularJustificacion(long idLeccion, string cedula)
    {
        await ausentismo.AnularJustificacionAsync(ActorId, idLeccion, cedula);
        return NoContent();
    }

    /// <summary>CU12: ausencias de cada estudiante de la sección contra las lecciones registradas en mi asignación
    /// (RN-70); filtro opcional ?semestre=. 404 (NF006/NF007); 403 (AD004).</summary>
    [HttpGet("ausentismo")]
    public async Task<IActionResult> Resumen([FromQuery] ConsultaAusentismo consulta) =>
        Ok(await ausentismo.ResumenProfesorAsync(ActorId, consulta));
}
