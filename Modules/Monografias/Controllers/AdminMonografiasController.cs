using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Monografias.Models;
using iet_bi_portal_backend.Modules.Monografias.Services;

namespace iet_bi_portal_backend.Modules.Monografias.Controllers;

/// <summary>Administrador CU34 a CU37 (asignar, consultar, modificar y eliminar asignaciones de monografía). Una monografía
/// se identifica por la cédula del estudiante (una por estudiante). Exige rol ADMIN.</summary>
[Route("api/admin/monografias")]
public class AdminMonografiasController(MonografiasService monografias) : AdminControllerBase
{
    /// <summary>CU34: 201. 404 (NF004/NF003/NF009/NF002/NF007); 409 (MO001) ya tiene monografía; 409 (MO002) materia no
    /// SUPERIOR/MEDIO; 409 (MO003) grupo de 5 lleno; 409 (MO004) no es una matrícula de nivel 10 sin retiro; 409 (MO005)
    /// coordinador sin COORD_MONOGRAFIA.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarMonografiaRequest request)
    {
        await monografias.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created);
    }

    /// <summary>CU35: listado paginado; filtros opcionales ?anioInicio=&amp;cedulaCoordinador=&amp;codigoAsignatura=&amp;estado=.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaMonografias consulta) =>
        Ok(await monografias.ListarAsync(ActorId, consulta));

    /// <summary>CU35: 404 (NF003/NF013).</summary>
    [HttpGet("{cedula}")]
    public async Task<IActionResult> Obtener(string cedula) => Ok(await monografias.ObtenerAsync(ActorId, cedula));

    /// <summary>CU36: cambia coordinador y/o materia. 404 (NF003/NF013/NF002/NF007); 409 (MO002/MO003/MO005).</summary>
    [HttpPut("{cedula}")]
    public async Task<IActionResult> Modificar(string cedula, ModificarMonografiaRequest request)
    {
        await monografias.ModificarAsync(ActorId, cedula, request);
        return NoContent();
    }

    /// <summary>CU37: 404 (NF003/NF013); 409 (23001) si ya tiene seguimiento o reportes.</summary>
    [HttpDelete("{cedula}")]
    public async Task<IActionResult> Eliminar(string cedula)
    {
        await monografias.EliminarAsync(ActorId, cedula);
        return NoContent();
    }
}
