using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;

namespace iet_bi_portal_backend.Config;

/// <summary>Registra la conexión a PostgreSQL (NpgsqlDataSource), armando el connection
/// string desde las variables del .env.</summary>
public static class DatabaseModule
{
    public static IServiceCollection AddDatabase(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = new NpgsqlConnectionStringBuilder
        {
            Host = EnvConfig.Required(configuration, "DB_HOST"),
            Port = EnvConfig.RequiredInt(configuration, "DB_PORT"),
            Database = EnvConfig.Required(configuration, "DB_NAME"),
            Username = EnvConfig.Required(configuration, "DB_USER"),
            Password = EnvConfig.Required(configuration, "DB_PASSWORD"),
        }.ConnectionString;

        services.TryAddSingleton(_ => NpgsqlDataSource.Create(connectionString));
        return services;
    }
}