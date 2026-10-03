using iet_bi_portal_backend.Modules.Profesores.Data;
using iet_bi_portal_backend.Modules.Profesores.Services;

namespace iet_bi_portal_backend.Modules.Profesores;

/// <summary>Administración de profesores. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class ProfesoresModule
{
    public static IServiceCollection AddProfesoresModule(this IServiceCollection services)
    {
        services.AddScoped<ProfesoresRepository>();
        services.AddScoped<ProfesoresService>();
        return services;
    }
}
