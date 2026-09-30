using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Secciones.Models;
using iet_bi_portal_backend.Modules.Secciones.Services;

namespace iet_bi_portal_backend.Modules.Secciones.Controllers;

/// <summary>Administrador CU18 a CU21 (registrar, consultar y eliminar secciones; asociar el profesor guía). Se opera siempre por (año, nivel, número), ej. /2026/10/1. Exige rol ADMIN.</summary>
[Route("api/admin/secciones")]
public class AdminSeccionesController(SeccionesService secciones) : AdminControllerBase
{
    private const string RutaSeccion = "{anio:int}/{nivel:int}/{numero:int}";

    /// <summary>CU18: 201 con el nombre; 404 (NF004) periodo inexistente; 400 (SE002) nivel/número; 409 (SE001) repetida;
    /// 409 (SE005) nivel 11 sin la 10-N del año anterior (RN-62). Para subir la sección con sus estudiantes: POST /api/admin/matriculas/subir-seccion.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar(RegistrarSeccionRequest request)
    {
        var nombre = await secciones.RegistrarAsync(ActorId, request);
        return StatusCode(StatusCodes.Status201Created, new { anio = request.Anio, nombre });
    }

    /// <summary>CU19: listado paginado; filtros opcionales ?anio=2026&amp;nivel=10.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] ConsultaSecciones consulta) =>
        Ok(await secciones.ListarAsync(consulta));

    /// <summary>CU19: detalle. 404 (NF006) si no existe.</summary>
    [HttpGet(RutaSeccion)]
    public async Task<IActionResult> Obtener(int anio, int nivel, int numero)
    {
        var seccion = await secciones.ObtenerAsync(anio, nivel, numero);
        return seccion is null ? this.ApiError("NF006") : Ok(seccion);
    }

    /// <summary>CU20: elimina la sección. 404 (NF006); 409 (23001) si tiene datos asociados; 409 (SE006) 10-N que ya continúa como 11-N.</summary>
    [HttpDelete(RutaSeccion)]
    public async Task<IActionResult> Eliminar(int anio, int nivel, int numero)
    {
        await secciones.EliminarAsync(ActorId, anio, nivel, numero);
        return NoContent();
    }

    /// <summary>CU21: asocia o reemplaza el guía. 404 (NF006/NF002); 409 (SE003) sin usuario activo con rol GUIA;
    /// 409 (SE004) ya es guía de otra sección del periodo.</summary>
    [HttpPut(RutaSeccion + "/guia")]
    public async Task<IActionResult> AsignarGuia(int anio, int nivel, int numero, AsignarGuiaRequest request)
    {
        await secciones.AsignarGuiaAsync(ActorId, anio, nivel, numero, request);
        return NoContent();
    }

    /// <summary>CU21: quita el guía. 204 aunque no tuviera; 404 (NF006).</summary>
    [HttpDelete(RutaSeccion + "/guia")]
    public async Task<IActionResult> QuitarGuia(int anio, int nivel, int numero)
    {
        await secciones.QuitarGuiaAsync(ActorId, anio, nivel, numero);
        return NoContent();
    }
}
