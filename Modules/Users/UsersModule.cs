using iet_bi_portal_backend.Modules.Users.Data;
using iet_bi_portal_backend.Modules.Users.Services;

namespace iet_bi_portal_backend.Modules.Users;

    /// <summary>Módulo de administración de usuarios (asignación/revocación de roles). Requiere
    /// que NpgsqlDataSource (lo registra DatabaseModule) e ILogsService (LogsModule) ya estén
    /// en el contenedor — no los vuelve a crear para no duplicar recursos.</summary>
public static class UsersModule
{
    public static IServiceCollection AddUsersModule(this IServiceCollection services)
    {
        services.AddScoped<UsersRepository>();
        services.AddScoped<UsersService>();
        return services;
    }
}