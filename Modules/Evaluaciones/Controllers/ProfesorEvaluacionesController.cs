using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Evaluaciones.Models;
using iet_bi_portal_backend.Modules.Evaluaciones.Services;

namespace iet_bi_portal_backend.Modules.Evaluaciones.Controllers;

/// <summary>Profesor Regular CU01 (pantalla principal), CU05 a CU08 (registrar, modificar y consultar evaluaciones y sus
/// observaciones) y CU13 (confirmar el registro de bandas al final del semestre). Solo el profesor de la asignación opera sus notas
/// (403 AD004), desde el inicio del semestre (409 EV002) hasta el cierre: fin del semestre o prórroga (409 EV003).</summary>
[Route("api/profesor")]
[Authorize(Roles = Roles.ProfesorRegular)]
public class ProfesorEvaluacionesController(EvaluacionesService evaluaciones) : ApiControllerBase
{
    /// <summary>CU01: mis asignaciones con el plazo de notas abierto, días para el cierre y aviso (RN-76).</summary>
    [HttpGet("pantalla-principal")]
    public async Task<IActionResult> PantallaPrincipal() => Ok(await evaluaciones.AvisosAsync(ActorId));

    /// <summary>CU07: estado y notas de mi asignación en el semestre (?anio&amp;nivel&amp;numero&amp;codigoAsignatura&amp;semestre).
    /// 404 (NF006/NF007); 403 (AD004).</summary>
    [HttpGet("evaluaciones")]
    public async Task<IActionResult> Listar([FromQuery] ConsultaNotasAsignacion consulta) =>
        Ok(await evaluaciones.ListarNotasAsync(ActorId, consulta));

    /// <summary>CU05 / CU06 / CU08: registra o corrige notas y observaciones hasta confirmar el semestre; el guía las ve desde ya.
    /// Una confirmación bloquea cambios posteriores (RN-75). 400 (EV001) nota fuera de la escala;
    /// 400 (EV004) estudiante que no se califica en la sección y semestre; 400 (EV005) repetido; 409 (EV002/EV003/EV008).</summary>
    [HttpPut("evaluaciones")]
    public async Task<IActionResult> Registrar(RegistrarNotasRequest request)
    {
        await evaluaciones.RegistrarNotasAsync(ActorId, request);
        return NoContent();
    }

    /// <summary>CU06: elimina la nota de un estudiante (corrección) antes de confirmar. 404 (NF009/NF016); 403 (AD004); 409 (EV002/EV003/EV008).</summary>
    [HttpDelete("evaluaciones/{anio:int}/{nivel:int}/{numero:int}/{codigo}/{semestre}/{cedula}")]
    public async Task<IActionResult> EliminarNota(int anio, int nivel, int numero, string codigo, string semestre, string cedula)
    {
        var asignacion = new ConsultaNotasAsignacion { Anio = anio, Nivel = nivel, Numero = numero, CodigoAsignatura = codigo, Semestre = semestre };
        await evaluaciones.EliminarNotaAsync(ActorId, asignacion, cedula);
        return NoContent();
    }

    /// <summary>CU13: confirma una sola vez las notas del semestre (RN-75), bloqueando cambios posteriores; el guía ve que están confirmadas.
    /// 204 también si ya estaban confirmadas. 409 (EV006) si falta alguna nota; 409 (EV002/EV003).</summary>
    [HttpPost("evaluaciones/confirmacion")]
    public async Task<IActionResult> Confirmar(ConsultaNotasAsignacion request)
    {
        await evaluaciones.ConfirmarNotasAsync(ActorId, request);
        return NoContent();
    }
}
