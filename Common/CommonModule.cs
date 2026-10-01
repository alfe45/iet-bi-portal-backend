using iet_bi_portal_backend.Common.Security;

namespace iet_bi_portal_backend.Common;

/// <summary>Servicios compartidos por todos los módulos de negocio.</summary>
public static class CommonModule
{
    public static IServiceCollection AddCommon(this IServiceCollection services)
    {
        services.AddSingleton<IContrasenaService, ContrasenaService>();
        return services;
    }
}
