using Microsoft.AspNetCore.Mvc;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary>Construye una respuesta { codigo, mensaje } a partir del catálogo, para los casos
/// en que el error no llega como excepción sino que el propio código de negocio decide
/// devolver una respuesta (credenciales inválidas, sesión expirada, etc.). Mantiene una sola
/// fuente de verdad para el mensaje: error_codes.json.</summary>
public static class ControllerBaseExtensions
{
    public static IActionResult ApiError(this ControllerBase controller, string codigo)
    {
        if (!ApiErrorCatalog.Errors.TryGetValue(codigo, out var info))
            throw new InvalidOperationException($"Código de error '{codigo}' no está en el catálogo.");

        return controller.StatusCode(info.Status, new { codigo, mensaje = info.Mensaje });
    }
}