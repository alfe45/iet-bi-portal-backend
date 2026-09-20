using iet_bi_portal_backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace iet_bi_portal_backend.Controllers;

[ApiController]
[Route("api/cursos-lectivos")]
// Endpoints para consultar y administrar cursos lectivos.
public sealed class CursosLectivosController(CursosLectivosService service) : ControllerBase
{
    [HttpGet]
    // Devuelve los cursos lectivos publicados.
    public async Task<ActionResult<IReadOnlyList<CursoLectivoResponse>>> Listar(CancellationToken cancellationToken)
        => Ok(await service.ListarAsync(cancellationToken));

    [HttpPost]
    // Valida y abre un curso lectivo.
    public async Task<ActionResult<object>> Abrir(CursoLectivoRequest request, CancellationToken cancellationToken)
    {
        var error = Validar(request);
        if (error is not null) return BadRequest(new { mensaje = error });
        return Created("/api/cursos-lectivos", new { idCursoLectivo = await service.AbrirAsync(request, cancellationToken) });
    }

    [HttpPut]
    // Valida y actualiza un curso lectivo.
    public async Task<ActionResult<object>> Actualizar(CursoLectivoRequest request, CancellationToken cancellationToken)
    {
        var error = Validar(request);
        if (error is not null) return BadRequest(new { mensaje = error });
        return Ok(new { idCursoLectivo = await service.ActualizarAsync(request, cancellationToken) });
    }

    [HttpDelete("{yearCiclo:int}")]
    // Borra un curso lectivo por año.
    public async Task<ActionResult<object>> Borrar(int yearCiclo, CancellationToken cancellationToken)
    {
        if (yearCiclo <= 0) return BadRequest(new { mensaje = "El campo 'Curso lectivo' debe ser válido." });
        return Ok(new { idCursoLectivo = await service.BorrarAsync(yearCiclo, cancellationToken) });
    }

    private static string? Validar(CursoLectivoRequest request)
    {
        if (!request.YearCiclo.HasValue) return "El campo 'Curso lectivo' es obligatorio y no puede estar vacío.";
        if (!request.FechaInicioI.HasValue) return "El campo 'Inicio del I semestre' es obligatorio y no puede estar vacío.";
        if (!request.FechaFinI.HasValue) return "El campo 'Fin del I semestre' es obligatorio y no puede estar vacío.";
        if (!request.FechaInicioII.HasValue) return "El campo 'Inicio del II semestre' es obligatorio y no puede estar vacío.";
        if (!request.FechaFinII.HasValue) return "El campo 'Fin del II semestre' es obligatorio y no puede estar vacío.";
        if (request.FechaInicioI.Value.Year != request.YearCiclo || request.FechaFinI.Value.Year != request.YearCiclo || request.FechaInicioII.Value.Year != request.YearCiclo || request.FechaFinII.Value.Year != request.YearCiclo) return "Todas las fechas deben pertenecer al curso lectivo seleccionado.";
        if (request.FechaFinI <= request.FechaInicioI) return "El fin del I semestre debe ser posterior a su inicio.";
        if (request.FechaFinII <= request.FechaInicioII) return "El fin del II semestre debe ser posterior a su inicio.";
        if (request.FechaInicioII <= request.FechaFinI) return "El II semestre debe iniciar después del I semestre.";
        return null;
    }
}
