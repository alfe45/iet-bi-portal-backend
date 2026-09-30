using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;

namespace iet_bi_portal_backend.Common.Controllers;

/// <summary>Base de todos los controllers: validación automática de [ApiController] y datos
/// del usuario autenticado / cliente, para no repetirlos en cada endpoint.</summary>
[ApiController]
public abstract class ApiControllerBase : ControllerBase
{
    /// <summary>Id del usuario autenticado (claim "sub"). Si falta responde 401 vía GlobalExceptionHandler.</summary>
    protected Guid ActorId => User.ObtenerIdUsuario() ?? throw new UnauthorizedAccessException();

    protected InfoCliente Cliente
    {
        get
        {
            var userAgent = Request.Headers.UserAgent.ToString();
            if (userAgent.Length > 300) userAgent = userAgent[..300];
            return new InfoCliente(HttpContext.Connection.RemoteIpAddress?.ToString(), userAgent);
        }
    }
}

/// <summary>Base de los controllers de administración: exige rol ADMIN.</summary>
[Authorize(Roles = Roles.Admin)]
public abstract class AdminControllerBase : ApiControllerBase
{
}
