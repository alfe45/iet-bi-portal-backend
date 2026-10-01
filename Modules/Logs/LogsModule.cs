using iet_bi_portal_backend.Modules.Logs.Data;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Logs;

public static class LogsModule
{
    /// <summary> Registra el servicio de auditoría (ILogsService), consumible desde cualquier
    /// otro módulo. Requiere que un NpgsqlDataSource ya esté registrado en el contenedor
    /// (hoy lo registra DatabaseModule) — no lo vuelve a crear acá para no duplicar la conexión. </summary>
    public static IServiceCollection AddLogsModule(this IServiceCollection services)
    {
        services.AddScoped<LogsRepository>();
        services.AddScoped<ILogsService, LogsService>();
        return services;
    }
}