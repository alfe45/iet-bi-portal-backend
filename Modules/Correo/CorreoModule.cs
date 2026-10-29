using iet_bi_portal_backend.Modules.Correo.Data;
using iet_bi_portal_backend.Modules.Correo.Services;

namespace iet_bi_portal_backend.Modules.Correo;

/// <summary>Correo del profesor a una sección. Requiere NpgsqlDataSource (DatabaseModule) e IServicioCorreo
/// (Common/Correo, AddServicioCorreo).</summary>
public static class CorreoModule
{
    public static IServiceCollection AddCorreoModule(this IServiceCollection services)
    {
        services.AddScoped<CorreoRepository>();
        services.AddScoped<CorreoService>();
        services.AddSingleton<LimiteEnviosCorreo>();
        return services;
    }
}
