using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Matriculas.Models;
using iet_bi_portal_backend.Modules.Matriculas.Services;

namespace iet_bi_portal_backend.Modules.Matriculas.Controllers;

/// <summary>Administrador CU22 a CU25 (matricular, modificar, consultar el historial y eliminar matrículas). Una matrícula se identifica por /{anio}/{cedulaEstudiante} (una por estudiante y año).
/// Exige rol ADMIN.</summary>
[Route("api/admin/matriculas")]
public class AdminMatriculasController(MatriculasService matriculas) : AdminControllerBase
{
    private const string RutaMatricula = "{anio:int}/{cedula}";

    /// <summary>CU22: 201. 404 (NF003/NF006); 409 (MA001) ya matriculado en el periodo; 409 (MA004/MA005)
    /// continuidad BI; 400 (ES003) edad fuera de 16-19 al inicio del periodo; 400 (MA002) fecha inválida.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarMatriculaRequest request)
    {
        await matriculas.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created);
    }

    /// <summary>CU22 - Subir la sección (RN-64): matricula en 11-N de Anio a todos los estudiantes sin retiro de la 10-N
    /// del año anterior (crea la 11-N si no existe, sin guía). Omite a quien ya tiene matrícula en el año, así que se puede
    /// repetir. 200 con { seccionCreada, matriculados, omitidos }. 404 (NF004/NF006); 400 (MA002) fecha inválida.</summary>
    [HttpPost("subir-seccion")]
    public async Task<IActionResult> SubirSeccion(SubirSeccionRequest request) =>
        Ok(await matriculas.SubirSeccionAsync(ActorId, request));

    /// <summary>CU24: listado / historial paginado; filtros opcionales ?anio=&amp;nivel=&amp;numero=&amp;cedulaEstudiante=
    /// &amp;estado=&amp;busqueda= (historial de un estudiante: ?cedulaEstudiante=).</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaMatriculas consulta) =>
        Ok(await matriculas.ListarAsync(consulta));

    /// <summary>CU24: detalle. 404 (NF009) si no existe.</summary>
    [HttpGet(RutaMatricula)]
    public async Task<IActionResult> Obtener(int anio, string cedula)
    {
        var matricula = await matriculas.ObtenerAsync(anio, cedula);
        return matricula is null ? this.ApiError("NF009") : Ok(matricula);
    }

    /// <summary>CU23: traslado a otra sección del mismo año. 404 (NF009/NF006).</summary>
    [HttpPut(RutaMatricula + "/seccion")]
    public async Task<IActionResult> CambiarSeccion(int anio, string cedula, CambiarSeccionRequest request)
    {
        await matriculas.CambiarSeccionAsync(ActorId, anio, cedula, request);
        return NoContent();
    }

    /// <summary>CU23: registra o corrige el retiro. 404 (NF009); 400 (MA003) fecha inválida.</summary>
    [HttpPut(RutaMatricula + "/retiro")]
    public async Task<IActionResult> RegistrarRetiro(int anio, string cedula, RegistrarRetiroRequest request)
    {
        await matriculas.RegistrarRetiroAsync(ActorId, anio, cedula, request);
        return NoContent();
    }

    /// <summary>CU23: anula el retiro (reingreso o corrección). 204 aunque no tuviera; 404 (NF009).</summary>
    [HttpDelete(RutaMatricula + "/retiro")]
    public async Task<IActionResult> AnularRetiro(int anio, string cedula)
    {
        await matriculas.AnularRetiroAsync(ActorId, anio, cedula);
        return NoContent();
    }

    /// <summary>CU25: elimina la matrícula. 404 (NF009); 409 (23001) si tiene registros asociados.</summary>
    [HttpDelete(RutaMatricula)]
    public async Task<IActionResult> Eliminar(int anio, string cedula)
    {
        await matriculas.EliminarAsync(ActorId, anio, cedula);
        return NoContent();
    }
}
