using iet_bi_portal_backend.Modules.Matriculas.Data;
using iet_bi_portal_backend.Modules.Matriculas.Services;

namespace iet_bi_portal_backend.Modules.Matriculas;

/// <summary>Matrículas de estudiantes en secciones. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class MatriculasModule
{
    public static IServiceCollection AddMatriculasModule(this IServiceCollection services)
    {
        services.AddScoped<MatriculasRepository>();
        services.AddScoped<MatriculasService>();
        return services;
    }
}
