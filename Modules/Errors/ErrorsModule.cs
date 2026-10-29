using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary> Registra el manejador global de excepciones y unifica el formato de los errores
/// de validación automática de [ApiController] (400 antes de llegar al controller) al mismo
/// contrato { codigo, mensaje } que usa GlobalExceptionHandler para todo lo demás. </summary>
public static class ErrorsModule
{
    public static IServiceCollection AddErrorsModule(this IServiceCollection services)
    {
        services.AddExceptionHandler<GlobalExceptionHandler>();
        services.AddProblemDetails();

        services.Configure<ApiBehaviorOptions>(options =>
        {
            options.InvalidModelStateResponseFactory = context =>
            {
                // Un formulario (multipart) que pasa el límite de tamaño falla al leerse durante el binding, sin excepción
                // (RP-17: no se lee el mensaje): 413, como los cuerpos JSON demasiado grandes en GlobalExceptionHandler.
                var limite = context.HttpContext.Features.Get<IHttpMaxRequestBodySizeFeature>()?.MaxRequestBodySize;
                if (limite is not null && context.HttpContext.Request.ContentLength > limite)
                    return new ObjectResult(new { codigo = "PAYLOAD_TOO_LARGE", mensaje = "La solicitud supera el tamaño máximo permitido." })
                    {
                        StatusCode = StatusCodes.Status413PayloadTooLarge
                    };

                var mensaje = string.Join(" ", context.ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage));

                return new ObjectResult(new { codigo = "VAERR", mensaje })
                {
                    StatusCode = StatusCodes.Status400BadRequest
                };
            };
        });

        return services;
    }
}