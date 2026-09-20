using iet_bi_portal_backend.Models;
using Microsoft.AspNetCore.Mvc;
using Npgsql;

namespace iet_bi_portal_backend.Controllers;

[ApiController]
[Route("api/secciones")]
// Endpoints para consultar y administrar secciones.
public sealed class SeccionesController(SeccionesService service) : ControllerBase
{
    [HttpGet]
    // Devuelve las secciones publicadas.
    public async Task<ActionResult<IReadOnlyList<SeccionResponse>>> Listar(CancellationToken cancellationToken)
        => Ok(await service.ListarAsync(cancellationToken));

    [HttpPost]
    // Valida y registra una sección.
    public async Task<ActionResult<object>> Registrar(RegistrarSeccionRequest request, CancellationToken cancellationToken)
    {
        var error = Validar(request);
        if (error is not null) return BadRequest(new { mensaje = error });
        try
        {
            return Created("/api/secciones", new { idSeccion = await service.RegistrarAsync(request, cancellationToken) });
        }
        catch (PostgresException exception)
        {
            return Conflict(new { mensaje = exception.MessageText });
        }
    }

    [HttpDelete("{yearCiclo:int}/{nivel:int}/{numeroSeccion:int}")]
    // Borra una sección por curso, nivel y número.
    public async Task<ActionResult<object>> Borrar(int yearCiclo, int nivel, int numeroSeccion, CancellationToken cancellationToken)
    {
        if (yearCiclo <= 0) return BadRequest(new { mensaje = "El campo 'Curso lectivo' debe ser válido." });
        if (nivel is not 10 and not 11) return BadRequest(new { mensaje = "El campo 'Nivel' debe ser 10 u 11." });
        if (numeroSeccion <= 0) return BadRequest(new { mensaje = "El campo 'Número de sección' debe ser mayor que cero." });
        try
        {
            return Ok(new { idSeccion = await service.BorrarAsync(yearCiclo, nivel, numeroSeccion, cancellationToken) });
        }
        catch (PostgresException exception)
        {
            return Conflict(new { mensaje = exception.MessageText });
        }
    }

    private static string? Validar(RegistrarSeccionRequest request)
    {
        if (!request.YearCiclo.HasValue) return "El campo 'Curso lectivo' es obligatorio y no puede estar vacío.";
        if (!request.Nivel.HasValue) return "El campo 'Nivel' es obligatorio y no puede estar vacío.";
        if (!request.NumeroSeccion.HasValue) return "El campo 'Número de sección' es obligatorio y no puede estar vacío.";
        if (request.YearCiclo <= 0) return "El campo 'Curso lectivo' debe ser válido.";
        if (request.Nivel is not 10 and not 11) return "El campo 'Nivel' debe ser 10 u 11.";
        if (request.NumeroSeccion <= 0) return "El campo 'Número de sección' debe ser mayor que cero.";
        return null;
    }
}
