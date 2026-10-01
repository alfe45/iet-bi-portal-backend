using iet_bi_portal_backend.Modules.Periodos.Data;
using iet_bi_portal_backend.Modules.Periodos.Services;

namespace iet_bi_portal_backend.Modules.Periodos;

/// <summary>Periodos académicos (año + dos semestres). Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class PeriodosModule
{
    public static IServiceCollection AddPeriodosModule(this IServiceCollection services)
    {
        services.AddScoped<PeriodosRepository>();
        services.AddScoped<PeriodosService>();
        return services;
    }
}
