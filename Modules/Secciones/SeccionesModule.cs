using iet_bi_portal_backend.Modules.Secciones.Data;
using iet_bi_portal_backend.Modules.Secciones.Services;

namespace iet_bi_portal_backend.Modules.Secciones;

/// <summary>Secciones (niveles 10 y 11) y su profesor guía. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class SeccionesModule
{
    public static IServiceCollection AddSeccionesModule(this IServiceCollection services)
    {
        services.AddScoped<SeccionesRepository>();
        services.AddScoped<SeccionesService>();
        return services;
    }
}
