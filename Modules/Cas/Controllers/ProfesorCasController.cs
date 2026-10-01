using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Cas.Models;
using iet_bi_portal_backend.Modules.Cas.Services;

namespace iet_bi_portal_backend.Modules.Cas.Controllers;

/// <summary>Profesor CAS CU01 a CU04 (registrar, modificar, consultar y eliminar información CAS). Un informe se identifica
/// por /{anio}/{semestre}/{cedula} del estudiante; solo lo opera el profesor CAS de su sección (403 AD004), en el plazo de
/// notas del semestre (409 EV002/EV003). La nota CAS se registra y envía con evaluaciones.</summary>
[Route("api/profesor/cas/informes")]
[Authorize(Roles = Roles.ProfesorCas)]
public class ProfesorCasController(CasService cas) : ApiControllerBase
{
    private const string RutaInforme = "{anio:int}/{semestre}/{cedula}";

    /// <summary>CU03: progreso de mi sección CAS en el semestre (?anio&amp;nivel&amp;numero&amp;semestre). 404 (NF006/NF007); 403 (AD004).</summary>
    [HttpGet]
    public async Task<IActionResult> Progreso([FromQuery] ConsultaProgresoSeccion consulta) =>
        Ok(await cas.ProgresoSeccionAsync(ActorId, consulta));

    /// <summary>CU03: informe completo. 404 (NF004/NF003/NF009/NF015); 403 (AD004).</summary>
    [HttpGet(RutaInforme)]
    public async Task<IActionResult> Obtener(int anio, string semestre, string cedula) =>
        Ok(await cas.ObtenerInformeAsync(ActorId, anio, semestre, cedula));

    /// <summary>CU01 / CU02: registra o reemplaza el informe (RN-83). 404 (NF004/NF003/NF009); 403 (AD004); 400 (EV004)
    /// estudiante que no se califica en el semestre; 400 (CA001) fecha de experiencia inválida; 409 (EV002/EV003).</summary>
    [HttpPut(RutaInforme)]
    public async Task<IActionResult> Guardar(int anio, string semestre, string cedula, GuardarInformeCasRequest request)
    {
        await cas.GuardarInformeAsync(ActorId, anio, semestre, cedula, request);
        return NoContent();
    }

    /// <summary>CU04: 404 (NF004/NF003/NF009/NF015); 403 (AD004); 409 (EV002/EV003).</summary>
    [HttpDelete(RutaInforme)]
    public async Task<IActionResult> Eliminar(int anio, string semestre, string cedula)
    {
        await cas.EliminarInformeAsync(ActorId, anio, semestre, cedula);
        return NoContent();
    }
}
