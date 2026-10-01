using iet_bi_portal_backend.Modules.Asignaciones.Data;
using iet_bi_portal_backend.Modules.Asignaciones.Services;

namespace iet_bi_portal_backend.Modules.Asignaciones;

/// <summary>Asignaciones docentes (profesor + asignatura + sección). Requiere NpgsqlDataSource (DatabaseModule)
/// e ILogsService (LogsModule).</summary>
public static class AsignacionesModule
{
    public static IServiceCollection AddAsignacionesModule(this IServiceCollection services)
    {
        services.AddScoped<AsignacionesRepository>();
        services.AddScoped<AsignacionesService>();
        return services;
    }
}
