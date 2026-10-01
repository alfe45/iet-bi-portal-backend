using System.Transactions;
using Microsoft.AspNetCore.Mvc.Filters;

namespace iet_bi_portal_backend.Common.Data;

/// <summary>Una petición que modifica datos (POST/PUT/PATCH/DELETE) se ejecuta en una sola transacción (RP-58): la
/// función SQL y la auditoría (ILogsService) se confirman juntas o no se confirma ninguna. Antes eran comandos separados
/// y, si fallaba el log, la operación quedaba hecha sin rastro y el cliente recibía un error (hallazgo QA-151).
/// Se confirma si la acción no lanzó excepción, aunque responda 4xx: el login fallido y la reutilización de un refresh
/// token deben quedar registrados. Npgsql reutiliza la misma conexión física dentro de la transacción (no escala a 2PC).</summary>
public sealed class TransaccionPorPeticionFilter : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        if (HttpMethods.IsGet(context.HttpContext.Request.Method) || HttpMethods.IsHead(context.HttpContext.Request.Method))
        {
            await next();
            return;
        }

        using var scope = new TransactionScope(
            TransactionScopeOption.Required,
            new TransactionOptions { IsolationLevel = IsolationLevel.ReadCommitted, Timeout = TimeSpan.FromSeconds(30) },
            TransactionScopeAsyncFlowOption.Enabled);

        var ejecutada = await next();

        if (ejecutada.Exception is null || ejecutada.ExceptionHandled)
            scope.Complete();
    }
}
