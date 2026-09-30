using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Matriculas.Models;
using iet_bi_portal_backend.Modules.Matriculas.Services;

namespace iet_bi_portal_backend.Modules.Matriculas.Controllers;

/// <summary>CU25 a CU28. Una matrícula se identifica por /{anio}/{cedulaEstudiante} (una por estudiante y año).
/// Exige rol ADMIN.</summary>
[Route("api/admin/matriculas")]
public class AdminMatriculasController(MatriculasService matriculas) : AdminControllerBase
{
    private const string RutaMatricula = "{anio:int}/{cedula}";

    /// <summary>CU25: 201. 404 (NF003/NF006); 409 (MA001) ya matriculado en el periodo;
    /// 400 (ES003) edad fuera de 16-19 al inicio del periodo; 400 (MA002) fecha inválida.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarMatriculaRequest request)
    {
        await matriculas.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created);
    }

    /// <summary>CU27: listado / historial paginado; filtros opcionales ?anio=&amp;nivel=&amp;numero=&amp;cedulaEstudiante=
    /// &amp;estado=&amp;busqueda= (historial de un estudiante: ?cedulaEstudiante=).</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaMatriculas consulta) =>
        Ok(await matriculas.ListarAsync(consulta));

    /// <summary>CU27: detalle. 404 (NF009) si no existe.</summary>
    [HttpGet(RutaMatricula)]
    public async Task<IActionResult> Obtener(int anio, string cedula)
    {
        var matricula = await matriculas.ObtenerAsync(anio, cedula);
        return matricula is null ? this.ApiError("NF009") : Ok(matricula);
    }

    /// <summary>CU26: traslado a otra sección del mismo año. 404 (NF009/NF006).</summary>
    [HttpPut(RutaMatricula + "/seccion")]
    public async Task<IActionResult> CambiarSeccion(int anio, string cedula, CambiarSeccionRequest request)
    {
        await matriculas.CambiarSeccionAsync(ActorId, anio, cedula, request);
        return NoContent();
    }

    /// <summary>CU26: registra o corrige el retiro. 404 (NF009); 400 (MA003) fecha inválida.</summary>
    [HttpPut(RutaMatricula + "/retiro")]
    public async Task<IActionResult> RegistrarRetiro(int anio, string cedula, RegistrarRetiroRequest request)
    {
        await matriculas.RegistrarRetiroAsync(ActorId, anio, cedula, request);
        return NoContent();
    }

    /// <summary>CU26: anula el retiro (reingreso o corrección). 204 aunque no tuviera; 404 (NF009).</summary>
    [HttpDelete(RutaMatricula + "/retiro")]
    public async Task<IActionResult> AnularRetiro(int anio, string cedula)
    {
        await matriculas.AnularRetiroAsync(ActorId, anio, cedula);
        return NoContent();
    }

    /// <summary>CU28: elimina la matrícula. 404 (NF009); 409 (23001) si tiene registros asociados.</summary>
    [HttpDelete(RutaMatricula)]
    public async Task<IActionResult> Eliminar(int anio, string cedula)
    {
        await matriculas.EliminarAsync(ActorId, anio, cedula);
        return NoContent();
    }
}
