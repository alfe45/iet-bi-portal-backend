using iet_bi_portal_backend.Modules.Asignaturas.Data;
using iet_bi_portal_backend.Modules.Asignaturas.Services;

namespace iet_bi_portal_backend.Modules.Asignaturas;

/// <summary>Catálogo de asignaturas. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class AsignaturasModule
{
    public static IServiceCollection AddAsignaturasModule(this IServiceCollection services)
    {
        services.AddScoped<AsignaturasRepository>();
        services.AddScoped<AsignaturasService>();
        return services;
    }
}
