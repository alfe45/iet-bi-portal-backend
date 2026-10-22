using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Profesores.Models;
using iet_bi_portal_backend.Modules.Profesores.Services;

namespace iet_bi_portal_backend.Modules.Profesores.Controllers;

/// <summary>Administrador CU06 a CU09 (registrar, consultar, modificar y eliminar profesores). Se opera siempre por cédula (RP-07). Exige rol ADMIN.</summary>
[Route("api/admin/profesores")]
public class AdminProfesoresController(ProfesoresService profesores) : AdminControllerBase
{
    /// <summary>CU06: 201 con la cédula. La cuenta (correo y contraseña) es obligatoria (RN-05); sin roles nace con
    /// PROFESOR_REGULAR. 409 (PR002) cédula en uso; 400 (NU001/NU002) correo o contraseña vacíos; 409 (TA001) correo
    /// en uso; 409 (AU021) rol único ya asignado.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarProfesorRequest request)
    {
        var cedula = await profesores.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { cedula });
    }

    /// <summary>CU07: listado paginado; ?busqueda= por nombre, apellidos, cédula o correo.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaConBusqueda consulta) =>
        Ok(await profesores.ListarAsync(ActorId, consulta));

    /// <summary>CU07: detalle por cédula. 404 (NF002) si no existe.</summary>
    [HttpGet("{cedula}")]
    public async Task<IActionResult> Obtener(string cedula)
    {
        var profesor = await profesores.ObtenerAsync(ActorId, cedula);
        return profesor is null ? this.ApiError("NF002") : Ok(profesor);
    }

    /// <summary>CU08: modifica un profesor (reemplazo completo de los campos editables). 404 (NF002) si no existe.</summary>
    [HttpPut("{cedula}")]
    public async Task<IActionResult> Actualizar(string cedula, ActualizarProfesorRequest request)
    {
        await profesores.ActualizarAsync(ActorId, cedula, request);
        return NoContent();
    }

    /// <summary>CU06: crea la cuenta (correo + contraseña + roles) de un profesor que no tiene, registrado antes de que
    /// fuera obligatoria. 201 con el id del usuario; 404 (NF002); 409 (PR007) ya tiene cuenta; mismos errores de cuenta que registrar.</summary>
    [HttpPost("{cedula}/cuenta")]
    public async Task<IActionResult> CrearCuenta(string cedula, CuentaProfesorRequest request)
    {
        var idUsuario = await profesores.CrearCuentaAsync(ActorId, cedula, request);
        return StatusCode(StatusCodes.Status201Created, new { idUsuario });
    }

    /// <summary>CU09: elimina el perfil de profesor y su cuenta (RN-07). 404 (NF002); 409 (PR004) es guía;
    /// 409 (AU012) es la propia cuenta; 409 (AU013) último administrador; 409 (PR009) asignaciones o monografías
    /// vigentes; 409 (23001) tiene registros académicos.</summary>
    [HttpDelete("{cedula}")]
    public async Task<IActionResult> Eliminar(string cedula)
    {
        await profesores.EliminarAsync(ActorId, cedula);
        return NoContent();
    }
}
