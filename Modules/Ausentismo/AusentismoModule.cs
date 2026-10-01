using iet_bi_portal_backend.Modules.Ausentismo.Data;
using iet_bi_portal_backend.Modules.Ausentismo.Services;

namespace iet_bi_portal_backend.Modules.Ausentismo;

/// <summary>Ausentismo por lección. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class AusentismoModule
{
    public static IServiceCollection AddAusentismoModule(this IServiceCollection services)
    {
        services.AddScoped<AusentismoRepository>();
        services.AddScoped<AusentismoService>();
        return services;
    }
}
