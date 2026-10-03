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