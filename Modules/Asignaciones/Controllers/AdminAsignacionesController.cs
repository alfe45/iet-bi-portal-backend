using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Asignaciones.Models;
using iet_bi_portal_backend.Modules.Asignaciones.Services;

namespace iet_bi_portal_backend.Modules.Asignaciones.Controllers;

/// <summary>Administrador CU30 a CU33 (asignar, consultar, modificar y eliminar asignaciones académicas). Una asignación se identifica por /{anio}/{nivel}/{numero}/{codigo}/{cedula}
/// (ej. /2026/10/1/MAT/1-1111-1111). Exige rol ADMIN.</summary>
[Route("api/admin/asignaciones")]
public class AdminAsignacionesController(AsignacionesService asignaciones) : AdminControllerBase
{
    private const string RutaAsignacion = "{anio:int}/{nivel:int}/{numero:int}/{codigo}/{cedula}";

    /// <summary>CU30: 201. 404 (NF006/NF007/NF002); 409 (AS005) la asignatura no se imparte en el nivel;
    /// 409 (AD001) repetida; 409 (AD002) el profesor no tiene usuario activo con PROFESOR_REGULAR.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarAsignacionRequest request)
    {
        await asignaciones.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created);
    }

    /// <summary>CU31: listado paginado; filtros opcionales ?anio=&amp;nivel=&amp;numero=&amp;codigoAsignatura=&amp;cedulaProfesor=.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaAsignaciones consulta) =>
        Ok(await asignaciones.ListarAsync(ActorId, consulta));

    /// <summary>CU32: reemplaza al profesor. 404 (NF008 y partes); 409 (AD001/AD002).</summary>
    [HttpPut(RutaAsignacion + "/profesor")]
    public async Task<IActionResult> CambiarProfesor(
        int anio, int nivel, int numero, string codigo, string cedula, CambiarProfesorRequest request)
    {
        await asignaciones.CambiarProfesorAsync(ActorId, anio, nivel, numero, codigo, cedula, request);
        return NoContent();
    }

    /// <summary>CU33: elimina la asignación. 404 (NF008 y partes); 409 (23001) si tiene registros asociados.</summary>
    [HttpDelete(RutaAsignacion)]
    public async Task<IActionResult> Eliminar(int anio, int nivel, int numero, string codigo, string cedula)
    {
        await asignaciones.EliminarAsync(ActorId, anio, nivel, numero, codigo, cedula);
        return NoContent();
    }
}
