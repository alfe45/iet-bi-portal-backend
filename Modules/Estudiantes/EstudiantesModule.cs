using iet_bi_portal_backend.Modules.Estudiantes.Data;
using iet_bi_portal_backend.Modules.Estudiantes.Services;

namespace iet_bi_portal_backend.Modules.Estudiantes;

/// <summary>Administración de estudiantes. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class EstudiantesModule
{
    public static IServiceCollection AddEstudiantesModule(this IServiceCollection services)
    {
        services.AddScoped<EstudiantesRepository>();
        services.AddScoped<EstudiantesService>();
        return services;
    }
}
