using iet_bi_portal_backend.Modules.Tablero.Data;
using iet_bi_portal_backend.Modules.Tablero.Services;

namespace iet_bi_portal_backend.Modules.Tablero;

/// <summary>Tablero del Administrador (solo lectura, RP-62). Requiere NpgsqlDataSource (DatabaseModule).</summary>
public static class TableroModule
{
    public static IServiceCollection AddTableroModule(this IServiceCollection services)
    {
        services.AddScoped<TableroRepository>();
        services.AddScoped<TableroService>();
        return services;
    }
}
