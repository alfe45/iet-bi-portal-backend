using iet_bi_portal_backend.Modules.Auth.Data;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Auth.Settings;
using iet_bi_portal_backend.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.Authorization;
using Npgsql;
using System.Text;
using System.Threading.RateLimiting;

namespace iet_bi_portal_backend.Modules.Auth;

public static class AuthModule
{
    /// <summary> Registra servicios, JWT, rate limiting y acceso a la DB del módulo, leyendo todo desde el .env </summary>
    public static IServiceCollection AddAuthModule(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // JWT
        var jwt = new JwtOptions
        {
            SecretKey = EnvConfig.Required(configuration, "JWT_KEY"),
            Issuer = EnvConfig.Required(configuration, "JWT_ISSUER"),
            Audience = EnvConfig.Required(configuration, "JWT_AUDIENCE"),
            AccessTokenMinutes = EnvConfig.RequiredInt(configuration, "JWT_ACCESS_MINUTES"),
            RefreshTokenDays = EnvConfig.RequiredInt(configuration, "JWT_REFRESH_DAYS"),
        };

        if (jwt.SecretKey.Length < 32)
            throw new InvalidOperationException(
                "JWT_KEY es demasiado corta para HMAC-SHA256. Usa al menos 32 caracteres aleatorios.");

        services.AddSingleton(Options.Create(jwt));

        // Política de login (intentos fallidos / bloqueo)
        var authPolicy = new AuthPolicyOptions
        {
            MaxFailedAttempts = EnvConfig.RequiredInt(configuration, "LOGIN_MAX_ATTEMPTS"),
            LockoutMinutes = EnvConfig.RequiredInt(configuration, "LOGIN_LOCKOUT_MINUTES"),
        };
        services.AddSingleton(Options.Create(authPolicy));

        // Token de inicialización: protege POST /api/setup/admin (creación del primer ADMIN)
        // además de la garantía que ya da la base de datos.
        var bootstrap = new BootstrapOptions
        {
            Secret = EnvConfig.Required(configuration, "ADMIN_BOOTSTRAP_TOKEN"),
        };

        if (bootstrap.Secret.Length < 16)
            throw new InvalidOperationException(
                "ADMIN_BOOTSTRAP_TOKEN es demasiado corto. Usa al menos 16 caracteres aleatorios.");

        services.AddSingleton(Options.Create(bootstrap));

        // PostgreSQL: se arma el connection string desde las 5 variables del .env
        var connectionString = new NpgsqlConnectionStringBuilder
        {
            Host = EnvConfig.Required(configuration, "DB_HOST"),
            Port = EnvConfig.RequiredInt(configuration, "DB_PORT"),
            Database = EnvConfig.Required(configuration, "DB_NAME"),
            Username = EnvConfig.Required(configuration, "DB_USER"),
            Password = EnvConfig.Required(configuration, "DB_PASSWORD"),
        }.ConnectionString;

        services.TryAddSingleton<NpgsqlDataSource>(_ => NpgsqlDataSource.Create(connectionString));

        // Servicios del módulo
        services.AddSingleton<IPasswordService, PasswordService>();
        services.AddSingleton<ITokenService, TokenService>();
        services.AddScoped<AuthRepository>();
        services.AddScoped<AuthService>();
        services.AddHostedService<SessionCleanupService>();

        // Autenticación JWT
        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = jwt.Issuer,
                    ValidateAudience = true,
                    ValidAudience = jwt.Audience,
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(30),
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SecretKey)),
                    ValidAlgorithms = new[] { SecurityAlgorithms.HmacSha256 },
                    RoleClaimType = AuthClaims.Role
                };
            });

        services.AddAuthorizationBuilder()
            .SetFallbackPolicy(new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .Build());

        // Límite de peticiones para /api/auth/* (60 por minuto por IP)
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.AddPolicy("auth", httpContext =>
                RateLimitPartition.GetFixedWindowLimiter(
                    httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 60,
                        Window = TimeSpan.FromMinutes(1)
                    }));
        });

        return services;
    }

    /// <summary> Agrega al pipeline: rate limiting, autenticación y autorización (en ese orden). </summary>
    public static IApplicationBuilder UseAuthModule(this IApplicationBuilder app)
    {
        app.UseRateLimiter();
        app.UseAuthentication();
        app.UseAuthorization();
        return app;
    }
}
