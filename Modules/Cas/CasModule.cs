using iet_bi_portal_backend.Modules.Cas.Data;
using iet_bi_portal_backend.Modules.Cas.Services;

namespace iet_bi_portal_backend.Modules.Cas;

/// <summary>Informes CAS. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class CasModule
{
    public static IServiceCollection AddCasModule(this IServiceCollection services)
    {
        services.AddScoped<CasRepository>();
        services.AddScoped<CasService>();
        return services;
    }
}
