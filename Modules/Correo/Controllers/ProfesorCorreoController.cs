using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Controllers;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Correo.Models;
using iet_bi_portal_backend.Modules.Correo.Services;
using iet_bi_portal_backend.Modules.Errors;

namespace iet_bi_portal_backend.Modules.Correo.Controllers;

/// <summary>Profesor Regular CU12: enviar documentos por correo a los estudiantes de una sección (RN-92), con el acceso de
/// RN-59 (imparte en la sección o es su guía; 403 AD003 si no).</summary>
[Route("api/profesor/secciones")]
[Authorize(Roles = Roles.ProfesorRegular)]
public class ProfesorCorreoController(CorreoService correo) : ApiControllerBase
{
    /// <summary>multipart/form-data: asunto, mensaje, cedulas (repetido; vacío = todos los estudiantes sin retiro) y
    /// adjuntos (repetido). 200 con los enviados y los fallidos. 400 (VAERR); 400 (CO001) tipo de archivo no permitido;
    /// 400 (CO002) más de 10 adjuntos, más de 10 MB o un archivo vacío; 404 (NF006); 403 (AD003); 404 (NF009) cédula
    /// no matriculada en la sección o retirada; 409 (CO003) nadie a quien enviar; 429 (CO005) más de 10 envíos por
    /// hora; 502 (CO004) no se pudo enviar a ninguno; 413 si la petición pasa de 11 MB.</summary>
    [HttpPost("{anio:int}/{nivel:int}/{numero:int}/correo")]
    [RequestSizeLimit(11 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 11 * 1024 * 1024)]
    public async Task<IActionResult> Enviar(int anio, int nivel, int numero, [FromForm] EnvioCorreoSeccion envio)
    {
        var resultado = await correo.EnviarSeccionAsync(ActorId, anio, nivel, numero, envio);
        return resultado.Envio is not null ? Ok(resultado.Envio) : this.ApiError(resultado.CodigoError!);
    }
}
