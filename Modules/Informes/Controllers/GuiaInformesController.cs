using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Informes.Models;
using iet_bi_portal_backend.Modules.Informes.Services;

namespace iet_bi_portal_backend.Modules.Informes.Controllers;

/// <summary>Guía CU08 (informe de notas de un estudiante) y CU09 (de toda la sección): reporte de bandas del semestre
/// (RN-85): las notas registradas hasta el momento y cuáles están confirmadas (RN-75), con el nombre del guía para la
/// línea de firma. El backend devuelve los datos y el front arma el PDF. 403 (AD005) si no es el guía de la sección.</summary>
[Route("api/profesor/guia/reporte-bandas")]
[Authorize(Roles = Roles.Guia)]
public class GuiaInformesController(InformesService informes) : ApiControllerBase
{
    /// <summary>CU09: ?anio&amp;nivel&amp;numero&amp;semestre. 404 (NF006).</summary>
    [HttpGet]
    public async Task<IActionResult> Seccion([FromQuery] ConsultaReporteBandas consulta) =>
        Ok(await informes.ReportesSeccionAsync(ActorId, consulta));

    /// <summary>CU08: 404 (NF006); 404 (NF009) si el estudiante no se califica en la sección ese semestre.</summary>
    [HttpGet("{cedula}")]
    public async Task<IActionResult> Estudiante(string cedula, [FromQuery] ConsultaReporteBandas consulta) =>
        Ok(await informes.ReporteEstudianteAsync(ActorId, consulta, cedula));

    /// <summary>Reactiva la edición de las notas confirmadas de la sección en el semestre (RN-75): cada profesor las corrige
    /// y vuelve a confirmar. 204 también si no había nada confirmado. 404 (NF006); 403 (AD005); 409 (EV003) si el plazo
    /// de notas ya cerró para todas las asignaturas confirmadas.</summary>
    [HttpPut("{anio:int}/{nivel:int}/{numero:int}/reactivar/{semestre}")]
    public async Task<IActionResult> ReactivarSeccion(int anio, int nivel, int numero, string semestre)
    {
        await informes.ReactivarBandasSeccionAsync(ActorId, new ConsultaReporteBandas { Anio = anio, Nivel = nivel, Numero = numero, Semestre = semestre });
        return NoContent();
    }
}
