using iet_bi_portal_backend.Modules.Monografias.Data;
using iet_bi_portal_backend.Modules.Monografias.Services;

namespace iet_bi_portal_backend.Modules.Monografias;

/// <summary>Monografías: asignación, estado, seguimiento y reportes al guía. Requiere NpgsqlDataSource (DatabaseModule) e
/// ILogsService (LogsModule).</summary>
public static class MonografiasModule
{
    public static IServiceCollection AddMonografiasModule(this IServiceCollection services)
    {
        services.AddScoped<MonografiasRepository>();
        services.AddScoped<MonografiasService>();
        return services;
    }
}
