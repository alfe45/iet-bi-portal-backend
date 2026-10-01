using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Evaluaciones.Models;
using iet_bi_portal_backend.Modules.Evaluaciones.Services;

namespace iet_bi_portal_backend.Modules.Evaluaciones.Controllers;

/// <summary>Administrador: prórrogas de notas (RN-74). Una prórroga da a un profesor más tiempo para registrar, corregir y
/// enviar las notas de un semestre; se identifica por /{anio}/{semestre}/{cedulaProfesor}. Exige rol ADMIN.</summary>
[Route("api/admin/prorrogas")]
public class AdminProrrogasController(EvaluacionesService evaluaciones) : AdminControllerBase
{
    private const string RutaProrroga = "{anio:int}/{semestre}/{cedula}";

    /// <summary>Listado con filtros opcionales ?anio=&amp;cedulaProfesor=.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaProrrogas consulta) =>
        Ok(await evaluaciones.ListarProrrogasAsync(ActorId, consulta));

    /// <summary>Otorga o cambia la prórroga. 404 (NF004/NF002); 400 (EV007) fecha no posterior al fin del semestre o pasada.</summary>
    [HttpPut(RutaProrroga)]
    public async Task<IActionResult> Otorgar(int anio, string semestre, string cedula, OtorgarProrrogaRequest request)
    {
        await evaluaciones.OtorgarProrrogaAsync(ActorId, anio, semestre, cedula, request);
        return NoContent();
    }

    /// <summary>Quita la prórroga. 404 (NF002/NF012).</summary>
    [HttpDelete(RutaProrroga)]
    public async Task<IActionResult> Quitar(int anio, string semestre, string cedula)
    {
        await evaluaciones.QuitarProrrogaAsync(ActorId, anio, semestre, cedula);
        return NoContent();
    }
}
