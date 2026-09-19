using iet_bi_portal_backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace iet_bi_portal_backend.Controllers;

[ApiController]
[Route("api/matriculas")]
// Endpoints para consultar y administrar matrículas.
public sealed class MatriculasController(MatriculasService service) : ControllerBase
{
    [HttpGet("estudiante/{cedula}")]
    // Consulta el historial de matrícula de un estudiante.
    public async Task<ActionResult<IReadOnlyList<MatriculaResponse>>> Listar(string cedula, CancellationToken cancellationToken)
    {
        var error = ValidarCedula(cedula);
        if (error is not null) return BadRequest(new { mensaje = error });
        return Ok(await service.ListarPorCedulaAsync(cedula, cancellationToken));
    }

    [HttpPost("nivel-10")]
    // Registra una matrícula de nivel 10.
    public async Task<ActionResult<object>> RegistrarNivel10(RegistrarMatriculaNivel10Request request, CancellationToken cancellationToken)
    {
        var error = ValidarNivel10(request);
        if (error is not null) return BadRequest(new { mensaje = error });
        return Created("/api/matriculas", new { idMatricula = await service.RegistrarNivel10Async(request, cancellationToken) });
    }

    [HttpPost("nivel-11")]
    // Ejecuta la promoción del estudiante a nivel 11.
    public async Task<ActionResult<object>> RegistrarNivel11([FromBody] string cedulaEstudiante, CancellationToken cancellationToken)
    {
        var error = ValidarCedula(cedulaEstudiante);
        if (error is not null) return BadRequest(new { mensaje = error });
        return Created("/api/matriculas", new { idMatricula = await service.RegistrarNivel11Async(cedulaEstudiante, cancellationToken) });
    }

    [HttpPatch("{idMatricula:long}/finalizar")]
    // Finaliza una matrícula existente.
    public async Task<ActionResult<object>> Finalizar(long idMatricula, CancellationToken cancellationToken)
    {
        if (idMatricula <= 0) return BadRequest(new { mensaje = "El campo 'Matrícula' debe ser válido." });
        return Ok(new { idMatricula = await service.FinalizarAsync(idMatricula, cancellationToken) });
    }

    [HttpDelete("{idMatricula:long}")]
    // Borra una matrícula existente.
    public async Task<ActionResult<object>> Borrar(long idMatricula, CancellationToken cancellationToken)
    {
        if (idMatricula <= 0) return BadRequest(new { mensaje = "El campo 'Matrícula' debe ser válido." });
        return Ok(new { idMatricula = await service.BorrarAsync(idMatricula, cancellationToken) });
    }

    private static string? ValidarNivel10(RegistrarMatriculaNivel10Request request)
    {
        var cedulaError = ValidarCedula(request.CedulaEstudiante);
        if (cedulaError is not null) return cedulaError;
        if (!request.YearCiclo.HasValue) return "El campo 'Año del ciclo lectivo' es obligatorio y no puede estar vacío.";
        if (!request.NumeroSeccion.HasValue) return "El campo 'Número de sección' es obligatorio y no puede estar vacío.";
        if (request.NumeroSeccion <= 0) return "El campo 'Número de sección' debe ser mayor que cero.";
        return null;
    }

    private static string? ValidarCedula(string? cedula)
    {
        if (string.IsNullOrWhiteSpace(cedula)) return "El campo 'Cédula del estudiante' es obligatorio y no puede estar vacío.";
        if (cedula.Trim().Length < 5) return "El campo 'Cédula del estudiante' debe tener al menos 5 caracteres.";
        return null;
    }
}
