using iet_bi_portal_backend.Modules.Evaluaciones.Data;
using iet_bi_portal_backend.Modules.Evaluaciones.Services;

namespace iet_bi_portal_backend.Modules.Evaluaciones;

/// <summary>Notas semestrales y prórrogas. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class EvaluacionesModule
{
    public static IServiceCollection AddEvaluacionesModule(this IServiceCollection services)
    {
        services.AddScoped<EvaluacionesRepository>();
        services.AddScoped<EvaluacionesService>();
        return services;
    }
}
