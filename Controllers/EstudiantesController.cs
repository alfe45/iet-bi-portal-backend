using System.Text.RegularExpressions;
using iet_bi_portal_backend.Models;
using Microsoft.AspNetCore.Mvc;

namespace iet_bi_portal_backend.Controllers;

[ApiController]
[Route("api/estudiantes")]
// Endpoints para consultar y administrar estudiantes.
public sealed class EstudiantesController(EstudiantesService service) : ControllerBase
{
    [HttpGet]
    // Devuelve la lista pública de estudiantes.
    public async Task<ActionResult<IReadOnlyList<EstudianteResponse>>> Listar(CancellationToken cancellationToken)
        => Ok(await service.ListarAsync(cancellationToken));

    [HttpPost]
    // Valida y registra un estudiante.
    public async Task<ActionResult<object>> Registrar(RegistrarEstudianteRequest request, CancellationToken cancellationToken)
    {
        var error = Validar(request.Nombre, request.PrimerApellido, request.Cedula, request.Email, request.FechaNacimiento);
        if (error is not null) return BadRequest(new { mensaje = error });
        var id = await service.RegistrarAsync(request, cancellationToken);
        return Created($"/api/estudiantes/{id}", new { idEstudiante = id });
    }

    [HttpPut("{cedulaActual}")]
    // Valida y actualiza un estudiante por su cédula actual.
    public async Task<ActionResult<object>> Actualizar(string cedulaActual, ActualizarEstudianteRequest request, CancellationToken cancellationToken)
    {
        var error = Validar(request.Nombre, request.PrimerApellido, request.Cedula, request.Email, request.FechaNacimiento);
        if (error is not null) return BadRequest(new { mensaje = error });
        return Ok(new { idEstudiante = await service.ActualizarAsync(cedulaActual, request, cancellationToken) });
    }

    [HttpDelete("{cedula}")]
    // Borra un estudiante por su cédula.
    public async Task<ActionResult<object>> Borrar(string cedula, CancellationToken cancellationToken)
        => Ok(new { idEstudiante = await service.BorrarAsync(cedula, cancellationToken) });

    private static string? Validar(string nombre, string primerApellido, string cedula, string email, DateOnly fechaNacimiento)
    {
        if (string.IsNullOrWhiteSpace(nombre)) return "El campo 'Nombre' es obligatorio y no puede estar vacío.";
        if (string.IsNullOrWhiteSpace(primerApellido)) return "El campo 'Primer apellido' es obligatorio y no puede estar vacío.";
        if (string.IsNullOrWhiteSpace(cedula)) return "El campo 'Cédula' es obligatorio y no puede estar vacío.";
        if (string.IsNullOrWhiteSpace(email)) return "El campo 'Correo electrónico' es obligatorio y no puede estar vacío.";
        if (nombre.Trim().Length < 2 || primerApellido.Trim().Length < 2) return "El nombre y el primer apellido deben tener al menos 2 caracteres.";
        if (cedula.Trim().Length < 5) return "La cédula debe tener al menos 5 caracteres.";
        if (!Regex.IsMatch(email.Trim(), "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")) return "El correo electrónico no tiene un formato válido.";
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (fechaNacimiento < today.AddYears(-19) || fechaNacimiento > today.AddYears(-16)) return "El estudiante debe tener entre 16 y 19 años.";
        return null;
    }
}
