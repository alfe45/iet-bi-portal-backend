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
    /// <summary>CU06: 201 con la cédula. La cuenta es opcional (RN-05): sin "cuenta" el profesor no inicia sesión.
    /// 409 (PR002) cédula en uso; errores de la cuenta: 400 (PR006) usuario existente y cuenta nueva a la vez o ninguno,
    /// 404 (NF001) usuario inexistente, 409 (PR001) el usuario ya tiene perfil, 400 (NU001/NU002) correo o contraseña vacíos,
    /// 409 (TA001) correo en uso.</summary>
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

    /// <summary>CU06: crea (correo + contraseña + roles) o vincula (idUsuario) la cuenta de un profesor que no tiene.
    /// 201 con el id del usuario; 404 (NF002); 409 (PR007) ya tiene cuenta; mismos errores de cuenta que registrar.</summary>
    [HttpPost("{cedula}/cuenta")]
    public async Task<IActionResult> CrearCuenta(string cedula, CuentaProfesorRequest request)
    {
        var idUsuario = await profesores.CrearCuentaAsync(ActorId, cedula, request);
        return StatusCode(StatusCodes.Status201Created, new { idUsuario });
    }

    /// <summary>CU09: quita la cuenta (elimina el usuario; el profesor y su historial se conservan). 404 (NF002);
    /// 409 (PR008) no tiene cuenta; 409 (AU012) es la propia cuenta; 409 (AU013) último administrador;
    /// 409 (AU020) tiene secciones, asignaciones o monografías vigentes.</summary>
    [HttpDelete("{cedula}/cuenta")]
    public async Task<IActionResult> QuitarCuenta(string cedula)
    {
        await profesores.QuitarCuentaAsync(ActorId, cedula);
        return NoContent();
    }

    /// <summary>CU09: elimina el perfil de profesor (su cuenta, si tiene, se conserva). 404 (NF002) si no existe.</summary>
    [HttpDelete("{cedula}")]
    public async Task<IActionResult> Eliminar(string cedula)
    {
        await profesores.EliminarAsync(ActorId, cedula);
        return NoContent();
    }
}
