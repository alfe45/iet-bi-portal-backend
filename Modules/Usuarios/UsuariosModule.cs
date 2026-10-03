using iet_bi_portal_backend.Modules.Usuarios.Data;
using iet_bi_portal_backend.Modules.Usuarios.Services;

namespace iet_bi_portal_backend.Modules.Usuarios;

/// <summary>Administración de usuarios y perfil propio. Requiere AddCommon(), NpgsqlDataSource (DatabaseModule)
/// e ILogsService (LogsModule).</summary>
public static class UsuariosModule
{
    public static IServiceCollection AddUsuariosModule(this IServiceCollection services)
    {
        services.AddScoped<UsuariosRepository>();
        services.AddScoped<UsuariosService>();
        return services;
    }
}
