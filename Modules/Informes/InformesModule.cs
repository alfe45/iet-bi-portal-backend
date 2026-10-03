using iet_bi_portal_backend.Modules.Informes.Data;
using iet_bi_portal_backend.Modules.Informes.Services;

namespace iet_bi_portal_backend.Modules.Informes;

/// <summary>Reporte de bandas del guía (solo lectura). Requiere NpgsqlDataSource (DatabaseModule).</summary>
public static class InformesModule
{
    public static IServiceCollection AddInformesModule(this IServiceCollection services)
    {
        services.AddScoped<InformesRepository>();
        services.AddScoped<InformesService>();
        return services;
    }
}
