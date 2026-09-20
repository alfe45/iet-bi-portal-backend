using iet_bi_portal_backend.Models;
using Microsoft.AspNetCore.Mvc;
using System.Text.RegularExpressions;

namespace iet_bi_portal_backend.Controllers;

[ApiController]
[Route("api/profesores")]
// Endpoints para consultar y administrar profesores.
public sealed class ProfesoresController(ProfesoresService service) : ControllerBase
{
    [HttpGet]
    // Devuelve la lista pública de profesores.
    public async Task<ActionResult<IReadOnlyList<ProfesorResponse>>> Listar(CancellationToken cancellationToken)
        => Ok(await service.ListarAsync(cancellationToken));

    [HttpPost]
    // Valida y registra un profesor.
    public async Task<ActionResult<object>> Registrar(RegistrarProfesorRequest request, CancellationToken cancellationToken)
    {
        var error = Validar(request.Nombre, request.PrimerApellido, request.Cedula, request.Email, request.FechaNacimiento, request.Password);
        if (error is not null) return BadRequest(new { mensaje = error });

        var id = await service.RegistrarAsync(request, cancellationToken);
        return Created($"/api/profesores/{id}", new { idProfesor = id });
    }

    [HttpPut("{cedulaActual}")]
    // Valida y actualiza un profesor por su cédula actual.
    public async Task<ActionResult<object>> Actualizar(string cedulaActual, ActualizarProfesorRequest request, CancellationToken cancellationToken)
    {
        var error = Validar(request.Nombre, request.PrimerApellido, request.Cedula, request.Email, request.FechaNacimiento, request.Password);
        if (error is not null) return BadRequest(new { mensaje = error });
        return Ok(new { idProfesor = await service.ActualizarAsync(cedulaActual, request, cancellationToken) });
    }

    [HttpPatch("{cedula}/activar")]
    // Activa un profesor mediante el procedimiento SQL oficial.
    public async Task<ActionResult<object>> Activar(string cedula, CancellationToken cancellationToken)
        => Ok(new { idProfesor = await service.ActivarAsync(cedula, cancellationToken) });

    [HttpPatch("{cedula}/desactivar")]
    // Desactiva un profesor mediante el procedimiento SQL oficial.
    public async Task<ActionResult<object>> Desactivar(string cedula, CancellationToken cancellationToken)
        => Ok(new { idProfesor = await service.DesactivarAsync(cedula, cancellationToken) });

    [HttpDelete("{cedula}")]
    // Borra un profesor por su cédula.
    public async Task<ActionResult<object>> Borrar(string cedula, CancellationToken cancellationToken)
        => Ok(new { idProfesor = await service.BorrarAsync(cedula, cancellationToken) });

    private static string? Validar(string nombre, string primerApellido, string cedula, string email, DateOnly fechaNacimiento, string password)
    {
        if (string.IsNullOrWhiteSpace(nombre)) return "El campo 'Nombre' es obligatorio y no puede estar vacío.";
        if (string.IsNullOrWhiteSpace(primerApellido)) return "El campo 'Primer apellido' es obligatorio y no puede estar vacío.";
        if (string.IsNullOrWhiteSpace(cedula)) return "El campo 'Cédula' es obligatorio y no puede estar vacío.";
        if (string.IsNullOrWhiteSpace(email)) return "El campo 'Correo electrónico' es obligatorio y no puede estar vacío.";
        if (string.IsNullOrWhiteSpace(password)) return "El campo 'Contraseña' es obligatorio y no puede estar vacío.";
        if (nombre.Trim().Length < 2 || primerApellido.Trim().Length < 2) return "El nombre y el primer apellido deben tener al menos 2 caracteres.";
        if (cedula.Trim().Length < 5) return "La cédula debe tener al menos 5 caracteres.";
        if (!Regex.IsMatch(email.Trim(), "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")) return "El correo electrónico no tiene un formato válido.";
        if (fechaNacimiento < new DateOnly(1900, 1, 1) || fechaNacimiento > DateOnly.FromDateTime(DateTime.UtcNow)) return "La fecha de nacimiento no es válida.";
        return null;
    }
}
