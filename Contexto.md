# Project Structure

```
iet-bi-portal-backend/
├── Common
│   └── Models
│       └── PaginationQuery.cs
├── Config
│   ├── DatabaseModule.cs
│   └── EnvConfig.cs
├── Modules
│   ├── Auth
│   │   ├── Controllers
│   │   │   ├── AuthController.cs
│   │   │   └── SetupController.cs
│   │   ├── Data
│   │   │   └── AuthRepository.cs
│   │   ├── Models
│   │   │   └── AuthModels..cs
│   │   ├── Security
│   │   │   ├── ClaimsPrincipalExtensions.cs
│   │   │   ├── Roles.cs
│   │   │   └── TokenService.cs
│   │   ├── Services
│   │   │   ├── AuthService.cs
│   │   │   ├── PasswordService.cs
│   │   │   └── SessionCleanupService.cs
│   │   ├── Settings
│   │   │   ├── AuthPolicyOptions.cs
│   │   │   ├── BootstrapOptions.cs
│   │   │   └── JwtOptions.cs
│   │   └── AuthModule.cs
│   ├── Errors
│   │   ├── ApiErrorCatalog.cs
│   │   ├── ControllerBaseExtensions.cs
│   │   ├── error_codes.json
│   │   ├── ErrorsModule.cs
│   │   └── GlobalExceptionHandler.cs
│   ├── Logs
│   │   ├── Data
│   │   │   └── LogsRepository.cs
│   │   ├── Services
│   │   │   └── LogsService.cs
│   │   ├── log_codes.md
│   │   └── LogsModule.cs
│   ├── Professors
│   │   ├── Controllers
│   │   │   └── AdminProfessorsController.cs
│   │   ├── Data
│   │   │   └── ProfessorsRepository.cs
│   │   ├── Models
│   │   │   └── ProfessorModels.cs
│   │   ├── Services
│   │   │   └── ProfessorsService.cs
│   │   └── ProfessorsModule.cs
│   ├── Students
│   │   ├── Controllers
│   │   │   └── AdminStudentsController.cs
│   │   ├── Data
│   │   │   └── StudentsRepository.cs
│   │   ├── Models
│   │   │   └── StudentModels.cs
│   │   ├── Services
│   │   │   └── StudentsService.cs
│   │   └── StudentsModule.cs
│   └── Users
│       ├── Controllers
│       │   └── AdminUsersController.cs
│       ├── Data
│       │   └── UsersRepository.cs
│       ├── Models
│       │   ├── ListUsersQuery.cs
│       │   ├── PagedResult.cs
│       │   ├── RegisterRequest.cs
│       │   ├── ResetPasswordRequest.cs
│       │   ├── RoleRequest.cs
│       │   ├── UpdateEmailRequest.cs
│       │   └── UserAdminRecord.cs
│       ├── Services
│       │   └── UsersService.cs
│       └── UsersModule.cs
├── Properties
│   └── launchSettings.json
├── Resources
│   └── sql
│       ├── 01_roles_schemas.sql
│       ├── 02_auth.sql
│       ├── 03_logs.sql
│       ├── 04_admin_usuarios.sql
│       ├── 05_db.sql
│       ├── 06_admin_profesores.sql
│       ├── 07_admin_estudiantes.sql
│       └── views.sql
├── .env.example
├── appsettings.Development.json
├── appsettings.json
├── Contexto.md
├── Dockerfile
├── iet-bi-portal-backend.csproj
├── iet-bi-portal-backend.http
├── iet-bi-portal-backend.slnx
├── Program.cs
└── README.md
```
# Project Structure

```
Common/
└── Models
    └── PaginationQuery.cs
```

# File Contents

## Common/Models/PaginationQuery.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Common;

/// <summary>Parámetros de paginación reutilizables para listados sin filtros.</summary>
public class PaginationQuery
{
    [Range(1, int.MaxValue, ErrorMessage = "La página debe ser mayor o igual a 1.")]
    public int Page { get; set; } = 1;

    [Range(1, 100, ErrorMessage = "El tamaño de página debe estar entre 1 y 100.")]
    public int PageSize { get; set; } = 20;
}
```

# Project Structure

```
Config/
├── DatabaseModule.cs
└── EnvConfig.cs
```

# File Contents

## Config/DatabaseModule.cs

```csharp
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
```

## Config/EnvConfig.cs

```csharp
// Config/EnvConfig.cs
namespace iet_bi_portal_backend.Config;

/// <summary>Lee variables de entorno requeridas. </summary>
public static class EnvConfig
{
    public static string Required(IConfiguration config, string key) =>
        config[key] is { Length: > 0 } value
            ? value
            : throw new InvalidOperationException(
                $"Falta la variable de entorno '{key}'. Revisa tu archivo .env.");

    public static int RequiredInt(IConfiguration config, string key)
    {
        var raw = Required(config, key);
        return int.TryParse(raw, out var value)
            ? value
            : throw new InvalidOperationException(
                $"La variable de entorno '{key}' debe ser un número entero (valor actual: '{raw}').");
    }
}
```

# Project Structure

```
Modules/
├── Auth
│   ├── Controllers
│   │   ├── AuthController.cs
│   │   └── SetupController.cs
│   ├── Data
│   │   └── AuthRepository.cs
│   ├── Models
│   │   └── AuthModels..cs
│   ├── Security
│   │   ├── ClaimsPrincipalExtensions.cs
│   │   ├── Roles.cs
│   │   └── TokenService.cs
│   ├── Services
│   │   ├── AuthService.cs
│   │   ├── PasswordService.cs
│   │   └── SessionCleanupService.cs
│   ├── Settings
│   │   ├── AuthPolicyOptions.cs
│   │   ├── BootstrapOptions.cs
│   │   └── JwtOptions.cs
│   └── AuthModule.cs
├── Errors
│   ├── ApiErrorCatalog.cs
│   ├── ControllerBaseExtensions.cs
│   ├── error_codes.json
│   ├── ErrorsModule.cs
│   └── GlobalExceptionHandler.cs
├── Logs
│   ├── Data
│   │   └── LogsRepository.cs
│   ├── Services
│   │   └── LogsService.cs
│   ├── log_codes.md
│   └── LogsModule.cs
├── Professors
│   ├── Controllers
│   │   └── AdminProfessorsController.cs
│   ├── Data
│   │   └── ProfessorsRepository.cs
│   ├── Models
│   │   └── ProfessorModels.cs
│   ├── Services
│   │   └── ProfessorsService.cs
│   └── ProfessorsModule.cs
├── Students
│   ├── Controllers
│   │   └── AdminStudentsController.cs
│   ├── Data
│   │   └── StudentsRepository.cs
│   ├── Models
│   │   └── StudentModels.cs
│   ├── Services
│   │   └── StudentsService.cs
│   └── StudentsModule.cs
└── Users
    ├── Controllers
    │   └── AdminUsersController.cs
    ├── Data
    │   └── UsersRepository.cs
    ├── Models
    │   ├── ListUsersQuery.cs
    │   ├── PagedResult.cs
    │   ├── RegisterRequest.cs
    │   ├── ResetPasswordRequest.cs
    │   ├── RoleRequest.cs
    │   ├── UpdateEmailRequest.cs
    │   └── UserAdminRecord.cs
    ├── Services
    │   └── UsersService.cs
    └── UsersModule.cs
```

# File Contents

## Modules/Auth/AuthModule.cs

```csharp
using iet_bi_portal_backend.Modules.Auth.Data;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Auth.Settings;
using iet_bi_portal_backend.Config;
using iet_bi_portal_backend.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.JsonWebTokens;
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
                // Revocación server-side: rechaza tokens emitidos antes de un logout-all,
                // cambio de contraseña o cambio de roles, aunque el JWT todavía no expiró.
                options.Events = new JwtBearerEvents
                {
                    OnTokenValidated = async context =>
                    {
                        var subClaim = context.Principal?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
                        var iatClaim = context.Principal?.FindFirst(JwtRegisteredClaimNames.Iat)?.Value;

                        if (!Guid.TryParse(subClaim, out var userId) || !long.TryParse(iatClaim, out var iatUnix))
                        {
                            context.Fail("Token inválido.");
                            return;
                        }

                        var repo = context.HttpContext.RequestServices.GetRequiredService<AuthRepository>();
                        var (exists, invalidatedSince) = await repo.GetTokenInvalidationWatermarkAsync(userId);

                        if (!exists)
                        {
                            context.Fail("El usuario ya no existe.");
                            return;
                        }

                        if (invalidatedSince is { } watermark)
                        {
                            var issuedAt = DateTimeOffset.FromUnixTimeSeconds(iatUnix).UtcDateTime;
                            if (issuedAt < watermark)
                                context.Fail("La sesión fue cerrada. Inicia sesión de nuevo.");
                        }
                    }
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

```

## Modules/Auth/Controllers/AuthController.cs

```csharp
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Users.Services;
using iet_bi_portal_backend.Modules.Errors;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.JsonWebTokens;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("auth")]
public class AuthController : ControllerBase
{
    private readonly AuthService _auth;
    private readonly UsersService _users;

    public AuthController(AuthService auth, UsersService users)
    {
        _auth = auth;
        _users = users;
    }

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var result = await _auth.LoginAsync(request.Email, request.Password, GetClientInfo());

        return result.Response is { } response
            ? Ok(response)
            : this.ApiError(result.ErrorCode!);
    }

    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutRequest request)
    {
        await _auth.LogoutAsync(request.RefreshToken, GetClientInfo());
        return NoContent();
    }

    /// <summary> Renueva el access token usando el refresh token. 
    /// Devuelve 200 OK con el nuevo access token y refresh token si la operación es exitosa,
    /// o 401 Unauthorized (AU007) si el refresh token es inválido o ha expirado. </summary>
    [AllowAnonymous]
    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh(RefreshRequest request)
    {
        var result = await _auth.RefreshAsync(request.RefreshToken, GetClientInfo());

        return result is null
            ? this.ApiError("AU007")
            : Ok(result);
    }

    /// <summary> Cierra todas las sesiones del usuario. </summary>
    [Authorize]
    [HttpPost("logout-all")]
    public async Task<IActionResult> LogoutAll()
    {
        if (User.GetUserId() is not { } userId) return Unauthorized();

        await _auth.LogoutAllAsync(userId);
        return NoContent();
    }

    /// <summary> Cambia la contraseña del usuario. 
    /// Devuelve 400 BadRequest (AU008) si la contraseña actual es incorrecta. </summary>
    [Authorize]
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request)
    {
        if (User.GetUserId() is not { } userId) return Unauthorized();

        var ok = await _auth.ChangePasswordAsync(userId, request.CurrentPassword, request.NewPassword);

        return ok
            ? NoContent()
            : this.ApiError("AU008");
    }

    /// <summary> Datos completos del usuario autenticado (mismo formato que CU03). Los roles vienen
    /// de la DB, no del token, así que reflejan el estado actual. </summary>
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        if (User.GetUserId() is not { } userId) return Unauthorized();

        var me = await _users.GetUserByIdAsync(userId);
        return me is null ? Unauthorized() : Ok(me);
    }
    
    /// <summary> Obtiene la información del cliente. </summary>
    private ClientInfo GetClientInfo()
    {
        var userAgent = Request.Headers.UserAgent.ToString();
        if (userAgent.Length > 300) userAgent = userAgent[..300];
        return new ClientInfo(HttpContext.Connection.RemoteIpAddress?.ToString(), userAgent);
    }
}
```

## Modules/Auth/Controllers/SetupController.cs

```csharp
using System.Security.Cryptography;
using System.Text;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Services;
using iet_bi_portal_backend.Modules.Auth.Settings;
using iet_bi_portal_backend.Modules.Errors;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace iet_bi_portal_backend.Modules.Auth.Controllers;

[ApiController]
[Route("api/setup")]
[EnableRateLimiting("auth")]
public class SetupController : ControllerBase
{
    private readonly AuthService _auth;
    private readonly BootstrapOptions _bootstrap;

    public SetupController(AuthService auth, IOptions<BootstrapOptions> bootstrap)
    {
        _auth = auth;
        _bootstrap = bootstrap.Value;
    }

    [AllowAnonymous]
    [HttpPost("first-admin")]
    public async Task<IActionResult> CreateFirstAdmin(
    BootstrapAdminRequest request,
    [FromHeader(Name = "X-Bootstrap-Token")] string? bootstrapToken)
    {
        if (!IsAuthorized(bootstrapToken))
            return this.ApiError("AU009");

        // Si ya existe el admin inicial o el correo está en uso, la excepción
        // sube desde la DB (AU001/TA001) y GlobalExceptionHandler la traduce.
        var userId = await _auth.BootstrapAdminAsync(request.Email, request.Password);

        return StatusCode(StatusCodes.Status201Created, new
        {
            id = userId,
            email = request.Email.Trim().ToLowerInvariant()
        });
    }

    private bool IsAuthorized(string? providedToken)
    {
        if (string.IsNullOrEmpty(_bootstrap.Secret) || string.IsNullOrEmpty(providedToken))
            return false;

        var expected = Encoding.UTF8.GetBytes(_bootstrap.Secret);
        var provided = Encoding.UTF8.GetBytes(providedToken);

        return expected.Length == provided.Length && CryptographicOperations.FixedTimeEquals(expected, provided);
    }
}
```

## Modules/Auth/Data/AuthRepository.cs

```csharp
using Npgsql;
using iet_bi_portal_backend.Modules.Auth.Models;

namespace iet_bi_portal_backend.Modules.Auth.Data;

public class AuthRepository
{
    private const string UserColumns = "id_usuario, email, password_hash, activo, bloqueado_hasta, roles::text[]";

    private readonly NpgsqlDataSource _db;

    public AuthRepository(NpgsqlDataSource db) => _db = db;

    /// <summary> Registra un nuevo usuario con rol PROFESOR_REGULAR. 
    /// Devuelve el ID del usuario si se creó correctamente, o null si el correo ya está en uso. </summary>
    public async Task<Guid?> RegisterUserAsync(string email, string passwordHash)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_registrar_usuario($1::academico.citext, $2)");
        cmd.Parameters.AddWithValue(email);
        cmd.Parameters.AddWithValue(passwordHash);
        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id ? id : null;
    }

    /// <summary> Crea el primer administrador del sistema. La función de base de datos serializa
    /// los intentos concurrentes con un advisory lock transaccional y falla (PostgresException,
    /// SqlState P0001) si ya existe un admin inicial o si el correo ya está en uso. </summary>
    public async Task<Guid> CreateFirstAdminAsync(string email, string passwordHash)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_crear_primer_admin($1::academico.citext, $2)");
        cmd.Parameters.AddWithValue(email);
        cmd.Parameters.AddWithValue(passwordHash);
        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id
            ? id
            : throw new InvalidOperationException("Respuesta inesperada de fn_crear_primer_admin.");
    }

    /// <summary> Obtiene un usuario por su correo electrónico. </summary>
    public Task<UserRecord?> GetUserByEmailAsync(string email) =>
        QueryUserAsync($"SELECT {UserColumns} FROM auth.fn_obtener_usuario_por_email($1::academico.citext)", email);

    /// <summary> Obtiene un usuario por su ID. </summary>
    public Task<UserRecord?> GetUserByIdAsync(Guid id) =>
        QueryUserAsync($"SELECT {UserColumns} FROM auth.fn_obtener_usuario_por_id($1)", id);

    /// <summary> Registra un intento fallido de inicio de sesión. </summary>
    public Task RegisterFailedLoginAsync(Guid userId, int maxAttempts, int lockoutMinutes) =>
        CallAsync("CALL auth.sp_registrar_login_fallido($1, $2, $3)", userId, maxAttempts, lockoutMinutes);

    /// <summary> Registra un intento exitoso de inicio de sesión. </summary>
    public Task RegisterSuccessfulLoginAsync(Guid userId) =>
        CallAsync("CALL auth.sp_registrar_login_exitoso($1)", userId);

    /// <summary> Cambia la contraseña del usuario. </summary>
    public Task ChangePasswordAsync(Guid userId, string newPasswordHash) =>
        CallAsync("CALL auth.sp_cambiar_contrasena($1, $2)", userId, newPasswordHash);

    /// <summary> Crea una nueva sesión para el usuario. </summary>
    public Task CreateSessionAsync(Guid userId, string tokenHash, DateTime expiresAtUtc, string? ip, string? userAgent) =>
        CallAsync("CALL auth.sp_crear_sesion($1, $2, $3, $4::text, $5::text)", userId, tokenHash, expiresAtUtc, ip, userAgent);

    /// <summary> Rota una sesión existente, reemplazando el refresh token antiguo por uno nuevo. </summary>
    public async Task<RotateResult> RotateSessionAsync(string oldTokenHash, string newTokenHash, DateTime newExpiresAtUtc, string? ip, string? userAgent)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT out_status, out_user_id, out_email, out_roles::text[] " +
            "FROM auth.fn_rotar_sesion($1, $2, $3, $4::text, $5::text)");
        cmd.Parameters.AddWithValue(oldTokenHash);
        cmd.Parameters.AddWithValue(newTokenHash);
        cmd.Parameters.AddWithValue(newExpiresAtUtc);
        cmd.Parameters.AddWithValue((object?)ip ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)userAgent ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();

        var status = reader.GetString(0);
        AuthenticatedUser? user = reader.IsDBNull(1)
            ? null
            : new AuthenticatedUser(
                reader.GetGuid(1),
                reader.GetString(2),
                reader.IsDBNull(3) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(3));

        return new RotateResult(status, user);
    }

    /// <summary> Cierra la sesión del refresh token dado. Devuelve el id del usuario dueño de la
    /// sesión, o null si el token no existía. </summary>
    public async Task<Guid?> LogoutAsync(string tokenHash)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_logout($1)");
        cmd.Parameters.AddWithValue(tokenHash);
        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id ? id : null;
    }

    /// <summary> Cierra todas las sesiones del usuario. </summary>
    public Task LogoutAllAsync(Guid userId) => CallAsync("CALL auth.sp_logout_all($1)", userId);

    /// <summary> Elimina las sesiones expiradas. </summary>
    public Task PurgeExpiredSessionsAsync() => CallAsync("CALL auth.sp_purgar_sesiones_expiradas()");

    /// <summary>Estado de revocación del usuario. Exists=false significa que el usuario fue eliminado
    /// (sus access tokens deben rechazarse). Watermark: fecha desde la cual los tokens emitidos antes
    /// se consideran revocados (logout-all, cambio de contraseña/roles, desactivación). Null si nunca se invalidó nada.</summary>
    public async Task<(bool Exists, DateTime? Watermark)> GetTokenInvalidationWatermarkAsync(Guid userId)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT tokens_invalidados_desde FROM api.usuarios WHERE id_usuario = $1");
        cmd.Parameters.AddWithValue(userId);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return (false, null);

        return (true, reader.IsDBNull(0) ? null : reader.GetDateTime(0));
    }

    /// <summary> Consulta un usuario y devuelve un UserRecord o null si no existe. </summary>
    private async Task<UserRecord?> QueryUserAsync(string sql, object param)
    {
        await using var cmd = _db.CreateCommand(sql);
        cmd.Parameters.AddWithValue(param);
        await using var reader = await cmd.ExecuteReaderAsync();

        if (!await reader.ReadAsync()) return null;

        return new UserRecord(
            reader.GetGuid(0),
            reader.GetString(1),
            reader.GetString(2),
            reader.GetBoolean(3),
            reader.IsDBNull(4) ? null : reader.GetDateTime(4),
            reader.IsDBNull(5) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(5));
    }

    /// <summary> Llama a una función de base de datos y devuelve su resultado. </summary>
    private async Task CallAsync(string sql, params object?[] args)
    {
        await using var cmd = _db.CreateCommand(sql);
        foreach (var arg in args)
            cmd.Parameters.AddWithValue(arg ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
    }
}
```

## Modules/Auth/Models/AuthModels..cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Auth.Models;

/// <summary> Datos para iniciar sesión. </summary>
public class LoginRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

/// <summary> Datos para renovar el access token usando el refresh token. </summary>
public class RefreshRequest
{
    [Required, MaxLength(200)]
    public string RefreshToken { get; set; } = string.Empty;
}

/// <summary> Datos para cerrar sesión (invalidar el refresh token). </summary>
public class LogoutRequest
{
    [Required, MaxLength(200)]
    public string RefreshToken { get; set; } = string.Empty;
}

/// <summary> Datos para cambiar la contraseña de un usuario autenticado. </summary>
public class ChangePasswordRequest
{
    [Required, MaxLength(128)]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string NewPassword { get; set; } = string.Empty;
}

/// <summary>Datos para crear el primer administrador del sistema (ver SetupController).</summary>
public class BootstrapAdminRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

/// <summary> Resultado de la autenticación. </summary>
public record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken);

/// <summary> Información del cliente que inicia sesión o renueva tokens. </summary>
public record ClientInfo(string? Ip, string? UserAgent);

/// <summary>Identidad + roles de un usuario ya autenticado, lista para emitir un token.</summary>
public record AuthenticatedUser(Guid Id, string Email, IReadOnlyList<string> Roles);

/// <summary> Registro de usuario obtenido de la base de datos. </summary>
public record UserRecord(Guid Id, string Email, string PasswordHash, bool IsActive, DateTime? LockoutUntil, IReadOnlyList<string> Roles);

/// <summary> Resultado de rotar un refresh token. </summary>
public record RotateResult(string Status, AuthenticatedUser? User);

/// <summary> Resultado del login: o hay respuesta con tokens, o un código de error del catálogo. </summary>
public record LoginResult(AuthResponse? Response, string? ErrorCode)
{
    public static LoginResult Success(AuthResponse response) => new(response, null);
    public static LoginResult Fail(string errorCode) => new(null, errorCode);
}

```

## Modules/Auth/Security/ClaimsPrincipalExtensions.cs

```csharp
using System.Security.Claims;
using Microsoft.IdentityModel.JsonWebTokens;

namespace iet_bi_portal_backend.Modules.Auth.Security;

/// <summary> Extensiones para ClaimsPrincipal. </summary>
public static class ClaimsPrincipalExtensions
{
    /// <summary> Obtiene el ID de usuario del claim "sub" (JWT Registered Claim Name). </summary>
    public static Guid? GetUserId(this ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirst(JwtRegisteredClaimNames.Sub)?.Value, out var id) ? id : null;

    /// <summary> Obtiene el correo electrónico del claim "email" (JWT Registered Claim Name). </summary>
    public static string? GetEmail(this ClaimsPrincipal user) =>
        user.FindFirst(JwtRegisteredClaimNames.Email)?.Value;
}
```

## Modules/Auth/Security/Roles.cs

```csharp
namespace iet_bi_portal_backend.Modules.Auth.Security;

/// <summary> Clase con las constantes de los roles de usuario. </summary>
public static class Roles
{
    public const string Admin  = "ADMIN";
    public const string ProfesorRegular = "PROFESOR_REGULAR";
    public const string ProfesorCas = "PROFESOR_CAS";
    public const string Guia = "GUIA";
    public const string CordinadorMonografia = "COORD_MONOGRAFIA";
    public const string CordinadorCAS = "COORD_CAS";
}

/// <summary> Clase con las constantes de los claims de usuario. </summary>
public static class AuthClaims
{
    public const string Role = "role";
}
```

## Modules/Auth/Security/TokenService.cs

```csharp
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using iet_bi_portal_backend.Modules.Auth.Settings;

namespace iet_bi_portal_backend.Modules.Auth.Security;

public record AccessToken(string Token, DateTime ExpiresAt);

/// <summary> Servicio para crear y validar tokens JWT y refresh tokens. </summary>
public interface ITokenService
{
    AccessToken CreateAccessToken(Guid userId, string email, IEnumerable<string> roles);
    string GenerateRefreshToken();
    string Hash(string token);
}

/// <summary> Servicio para crear y validar tokens JWT y refresh tokens. </summary>
public class TokenService : ITokenService
{
    private readonly JwtOptions _jwt;
    private readonly SigningCredentials _credentials;
    private readonly JsonWebTokenHandler _handler = new();

    /// <summary> Crea un servicio para crear y validar tokens JWT y refresh tokens. </summary>
    public TokenService(IOptions<JwtOptions> options)
    {
        _jwt = options.Value;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.SecretKey));
        _credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
    }

    /// <summary> Crea un access token JWT para un usuario autenticado. </summary>
    public AccessToken CreateAccessToken(Guid userId, string email, IEnumerable<string> roles)
    {
        var now = DateTime.UtcNow;
        var expires = now.AddMinutes(_jwt.AccessTokenMinutes);

        var claims = new List<Claim>
    {
        new(JwtRegisteredClaimNames.Sub, userId.ToString()),
        new(JwtRegisteredClaimNames.Email, email),
        new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
    };
        claims.AddRange(roles.Select(r => new Claim(AuthClaims.Role, r)));

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Issuer = _jwt.Issuer,
            Audience = _jwt.Audience,
            IssuedAt = now, // <- explícito, lo usa la revocación
            Expires = expires,
            SigningCredentials = _credentials
        };

        return new AccessToken(_handler.CreateToken(descriptor), expires);
    }

    /// <summary> Genera un refresh token aleatorio de 32 bytes codificado en hexadecimal. </summary>
    public string GenerateRefreshToken() => Convert.ToHexString(RandomNumberGenerator.GetBytes(32));

    /// <summary> Calcula el hash SHA256 de un refresh token. </summary>
    public string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
```

## Modules/Auth/Services/AuthService.cs

```csharp
using Microsoft.Extensions.Options;
using iet_bi_portal_backend.Security;
using iet_bi_portal_backend.Modules.Auth.Data;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Settings;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Auth.Services;

public class AuthService
{
    private readonly AuthRepository _repo;
    private readonly IPasswordService _passwords;
    private readonly ITokenService _tokens;
    private readonly JwtOptions _jwt;
    private readonly AuthPolicyOptions _policy;
    private readonly ILogsService _logs;

    public AuthService(
        AuthRepository repo,
        IPasswordService passwords,
        ITokenService tokens,
        IOptions<JwtOptions> jwt,
        IOptions<AuthPolicyOptions> policy,
        ILogsService logs)
    {
        _repo = repo;
        _passwords = passwords;
        _tokens = tokens;
        _jwt = jwt.Value;
        _policy = policy.Value;
        _logs = logs;
    }

    public async Task<LoginResult> LoginAsync(string email, string password, ClientInfo client)
    {
        email = NormalizeEmail(email);
        var user = await _repo.GetUserByEmailAsync(email);

        // Correo inexistente: gasta el mismo tiempo que una verificación real.
        if (user is null)
        {
            _passwords.VerifyDummy(password);
            return LoginResult.Fail("AU006");
        }

        var isLocked = user.LockoutUntil > DateTime.UtcNow;

        // Contraseña incorrecta: siempre genérico (no revela si la cuenta existe ni su estado).
        // Solo cuenta como intento fallido si la cuenta está activa y no bloqueada.
        if (!_passwords.Verify(password, user.PasswordHash))
        {
            if (user.IsActive && !isLocked)
                await _repo.RegisterFailedLoginAsync(user.Id, _policy.MaxFailedAttempts, _policy.LockoutMinutes);
            return LoginResult.Fail("AU006");
        }

        // Contraseña correcta: recién acá es seguro explicar el estado de la cuenta.
        if (!user.IsActive) return LoginResult.Fail("AU014");
        if (isLocked) return LoginResult.Fail("AU015");

        // Sin roles (solo por edición manual de la DB): fail-closed, sin filtrar el motivo.
        if (user.Roles.Count == 0) return LoginResult.Fail("AU006");

        await _repo.RegisterSuccessfulLoginAsync(user.Id);
        await _logs.RegisterLogAsync(user.Id, "LOGIN", ip: client.Ip, userAgent: client.UserAgent);
        return LoginResult.Success(await IssueSessionAsync(user.Id, user.Email, user.Roles, client));
    }

    public async Task LogoutAsync(string refreshToken, ClientInfo client)
    {
        var userId = await _repo.LogoutAsync(_tokens.Hash(refreshToken));

        // Token inexistente: no se loguea nada (evita ruido/abuso del endpoint anónimo).
        if (userId is null) return;

        await _logs.RegisterLogAsync(userId, "LOGOUT", "api.usuarios", userId.Value.ToString(),
            ip: client.Ip, userAgent: client.UserAgent);
    }
    public async Task<AuthResponse?> RefreshAsync(string refreshToken, ClientInfo client)
    {
        var newRefreshToken = _tokens.GenerateRefreshToken();

        var result = await _repo.RotateSessionAsync(
            _tokens.Hash(refreshToken),
            _tokens.Hash(newRefreshToken),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays),
            client.Ip,
            client.UserAgent);

        if (result.Status != "ok" || result.User is null || result.User.Roles.Count == 0) return null;

        var access = _tokens.CreateAccessToken(result.User.Id, result.User.Email, result.User.Roles);
        return new AuthResponse(access.Token, access.ExpiresAt, newRefreshToken);
    }

    public async Task LogoutAllAsync(Guid userId)
    {
        await _repo.LogoutAllAsync(userId);
        await _logs.RegisterLogAsync(userId, "LOGOUT_ALL", "api.usuarios", userId.ToString());
    }

    public async Task<bool> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword)
    {
        var user = await _repo.GetUserByIdAsync(userId);
        if (user is null || !user.IsActive || !_passwords.Verify(currentPassword, user.PasswordHash))
            return false;

        await _repo.ChangePasswordAsync(userId, _passwords.Hash(newPassword));
        // Nunca se loguea el hash ni la contraseña, solo el hecho de que cambió.
        await _logs.RegisterLogAsync(userId, "CHANGE_PASSWORD", "api.usuarios", userId.ToString());
        return true;
    }

    /// <summary>Crea el primer administrador. Si ya existe o el correo está en uso, la
    /// excepción de Postgres (AU001/TA001) sube tal cual — la traduce GlobalExceptionHandler.</summary>
    public async Task<Guid> BootstrapAdminAsync(string email, string password)
    {
        email = NormalizeEmail(email);
        var userId = await _repo.CreateFirstAdminAsync(email, _passwords.Hash(password));
        await _logs.RegisterLogAsync(userId, "BOOTSTRAP_ADMIN", "api.usuarios", userId.ToString());
        return userId;
    }

    private async Task<AuthResponse> IssueSessionAsync(Guid userId, string email, IReadOnlyList<string> roles, ClientInfo client)
    {
        var refreshToken = _tokens.GenerateRefreshToken();

        await _repo.CreateSessionAsync(
            userId,
            _tokens.Hash(refreshToken),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays),
            client.Ip,
            client.UserAgent);

        var access = _tokens.CreateAccessToken(userId, email, roles);
        return new AuthResponse(access.Token, access.ExpiresAt, refreshToken);
    }

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();
}
```

## Modules/Auth/Services/PasswordService.cs

```csharp
using System.Security.Cryptography;

namespace iet_bi_portal_backend.Security;

public interface IPasswordService
{
    string Hash(string password);
    bool Verify(string password, string storedHash);
    void VerifyDummy(string password);
}

public class PasswordService : IPasswordService
{
    private const string Version = "v1";
    private const int SaltSize = 16;
    private const int KeySize = 32;
    private const int Iterations = 600_000;   // recomendación OWASP para PBKDF2-SHA256

    private readonly string _dummyHash;

    /// <summary> Singleton: este hash falso se calcula una sola vez. </summary>
    public PasswordService() => _dummyHash = Hash("dummy-password-for-timing");

    /// <summary> Crea un hash de la contraseña. </summary>
    public string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var key = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, KeySize);
        return $"{Version}.{Iterations}.{Convert.ToBase64String(salt)}.{Convert.ToBase64String(key)}";
    }

    /// <summary> Verifica si la contraseña coincide con el hash almacenado. </summary>
    public bool Verify(string password, string storedHash)
    {
        var parts = storedHash.Split('.');
        if (parts.Length != 4 || parts[0] != Version || !int.TryParse(parts[1], out var iterations))
            return false;

        byte[] salt, expected;
        try
        {
            salt = Convert.FromBase64String(parts[2]);
            expected = Convert.FromBase64String(parts[3]);
        }
        catch (FormatException) { return false; }

        var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);   // tiempo constante
    }

    /// <summary> Gasta el mismo tiempo que un Verify real, para no revelar si un correo existe. </summary>
    public void VerifyDummy(string password) => Verify(password, _dummyHash);
}
```

## Modules/Auth/Services/SessionCleanupService.cs

```csharp
using iet_bi_portal_backend.Modules.Auth.Data;

namespace iet_bi_portal_backend.Modules.Auth.Services;

/// <summary>Corre auth.sp_purgar_sesiones_expiradas() una vez al día, en segundo plano.</summary>
public class SessionCleanupService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(24);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SessionCleanupService> _logger;

    /// <summary> Crea un servicio de limpieza de sesiones expiradas. </summary>
    public SessionCleanupService(IServiceScopeFactory scopeFactory, ILogger<SessionCleanupService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary> Ejecuta el servicio en segundo plano, purgando sesiones expiradas cada 24 horas. </summary>
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var repo = scope.ServiceProvider.GetRequiredService<AuthRepository>();
                await repo.PurgeExpiredSessionsAsync();
                _logger.LogInformation("Sesiones expiradas purgadas correctamente.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al purgar sesiones expiradas.");
            }

            try { await Task.Delay(Interval, stoppingToken); }
            catch (TaskCanceledException) { /* apagado normal */ }
        }
    }
}
```

## Modules/Auth/Settings/AuthPolicyOptions.cs

```csharp
namespace iet_bi_portal_backend.Modules.Auth.Settings;

public class AuthPolicyOptions
{
    public int MaxFailedAttempts { get; set; } = 5;
    public int LockoutMinutes { get; set; } = 15;
}
```

## Modules/Auth/Settings/BootstrapOptions.cs

```csharp
namespace iet_bi_portal_backend.Modules.Auth.Settings;

// Token compartido requerido para poder llamar al endpoint de inicialización
// del primer administrador (POST /api/setup/admin). Es una capa adicional a
// la protección que ya da la base de datos (solo permite crear un admin
// inicial una única vez, de forma segura ante condiciones de carrera).
public class BootstrapOptions
{
    public string Secret { get; set; } = string.Empty;
}

```

## Modules/Auth/Settings/JwtOptions.cs

```csharp
namespace iet_bi_portal_backend.Modules.Auth.Settings;

public class JwtOptions
{
    public string SecretKey { get; set; } = string.Empty;
    public string Issuer { get; set; } = string.Empty;
    public string Audience { get; set; } = string.Empty;
    public int AccessTokenMinutes { get; set; } = 15;
    public int RefreshTokenDays { get; set; } = 7;
}
```

## Modules/Errors/ApiErrorCatalog.cs

```csharp
using System.Text.Json;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary>
/// Diccionario central: para cada código (propio, lanzado por auth.fn_lanzar_excepcion,
/// o nativo de Postgres) define el status HTTP y el mensaje seguro para el cliente.
/// Se carga una sola vez desde error_codes.json. Un código que no está en el diccionario
/// nunca se expone tal cual — GlobalExceptionHandler responde 500 genérico.
///
/// Para agregar errores de otro módulo: se agregan las claves nuevas directamente en
/// error_codes.json. No hace falta tocar esta clase.
/// </summary>
public static class ApiErrorCatalog
{
    public sealed record ApiErrorInfo(int Status, string Mensaje);

    private sealed record ErrorJson(int Status, string Mensaje);

    private static readonly string FilePath =
        Path.Combine(AppContext.BaseDirectory, "Modules", "Errors", "error_codes.json");

    public static readonly IReadOnlyDictionary<string, ApiErrorInfo> Errors = Load();

    private static IReadOnlyDictionary<string, ApiErrorInfo> Load()
    {
        if (!File.Exists(FilePath))
            throw new InvalidOperationException(
                $"No se encontró el catálogo de errores en '{FilePath}'. " +
                "Verifica que error_codes.json esté configurado para copiarse al output.");

        var json = File.ReadAllText(FilePath);
        var raw = JsonSerializer.Deserialize<Dictionary<string, ErrorJson>>(
            json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        if (raw is null || raw.Count == 0)
            throw new InvalidOperationException("error_codes.json está vacío o mal formado.");

        return raw.ToDictionary(kv => kv.Key, kv => new ApiErrorInfo(kv.Value.Status, kv.Value.Mensaje));
    }
}
```

## Modules/Errors/ControllerBaseExtensions.cs

```csharp
using Microsoft.AspNetCore.Mvc;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary>Construye una respuesta { codigo, mensaje } a partir del catálogo, para los casos
/// en que el error no llega como excepción sino que el propio código de negocio decide
/// devolver una respuesta (credenciales inválidas, sesión expirada, etc.). Mantiene una sola
/// fuente de verdad para el mensaje: error_codes.json.</summary>
public static class ControllerBaseExtensions
{
    public static IActionResult ApiError(this ControllerBase controller, string codigo)
    {
        if (!ApiErrorCatalog.Errors.TryGetValue(codigo, out var info))
            throw new InvalidOperationException($"Código de error '{codigo}' no está en el catálogo.");

        return controller.StatusCode(info.Status, new { codigo, mensaje = info.Mensaje });
    }
}
```

## Modules/Errors/ErrorsModule.cs

```csharp
using Microsoft.AspNetCore.Mvc;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary> Registra el manejador global de excepciones y unifica el formato de los errores
/// de validación automática de [ApiController] (400 antes de llegar al controller) al mismo
/// contrato { codigo, mensaje } que usa GlobalExceptionHandler para todo lo demás. </summary>
public static class ErrorsModule
{
    public static IServiceCollection AddErrorsModule(this IServiceCollection services)
    {
        services.AddExceptionHandler<GlobalExceptionHandler>();
        services.AddProblemDetails();

        services.Configure<ApiBehaviorOptions>(options =>
        {
            options.InvalidModelStateResponseFactory = context =>
            {
                var mensaje = string.Join(" ", context.ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage));

                return new ObjectResult(new { codigo = "VAERR", mensaje })
                {
                    StatusCode = StatusCodes.Status400BadRequest
                };
            };
        });

        return services;
    }
}
```

## Modules/Errors/error_codes.json

```json
{
  "AU014": { "status": 403, "mensaje": "La cuenta está desactivada. Contacta a un administrador." },
  "AU015": { "status": 403, "mensaje": "La cuenta está bloqueada temporalmente por demasiados intentos fallidos. Intenta de nuevo más tarde." },

  "PR001": { "status": 409, "mensaje": "El usuario ya tiene un perfil de profesor." },
  "PR002": { "status": 409, "mensaje": "Ya existe un profesor con esa cédula." },
  "PR003": { "status": 409, "mensaje": "No se puede eliminar un usuario que tiene un perfil de profesor. Elimina primero el perfil." },

  "ES001": { "status": 409, "mensaje": "Ya existe un estudiante con esa cédula." },
  "ES002": { "status": 409, "mensaje": "Ya existe un estudiante con ese correo." },
  "ES003": { "status": 400, "mensaje": "El estudiante debe tener entre 16 y 19 años." },

  "NF002": { "status": 404, "mensaje": "El profesor no existe." },
  "NF003": { "status": 404, "mensaje": "El estudiante no existe." },

  "23502": { "status": 400, "mensaje": "Falta un valor obligatorio." },
  "23514": { "status": 400, "mensaje": "Uno de los valores enviados no cumple las reglas de validación." },
  "23503": { "status": 409, "mensaje": "La operación entra en conflicto con registros relacionados (el registro referenciado no existe o todavía tiene datos asociados)." }
}
```

## Modules/Errors/GlobalExceptionHandler.cs

```csharp
using Microsoft.AspNetCore.Diagnostics;
using Npgsql;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary>
/// Único punto de manejo de excepciones no capturadas. Respuesta siempre con
/// forma { codigo, mensaje }. Solo se exponen al cliente los códigos que están
/// catalogados en ApiErrorCatalog, con un mensaje fijo y seguro; cualquier otro
/// error (de Postgres o no) responde 500 genérico y nunca filtra texto interno
/// del motor (message/detail de Postgres pueden contener datos del usuario).
/// </summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception ex, CancellationToken ct)
    {
        var (status, codigo, mensaje) = ex switch
        {
            PostgresException pg when ApiErrorCatalog.Errors.TryGetValue(pg.SqlState ?? "", out var info)
                => (info.Status, pg.SqlState!, info.Mensaje),

            PostgresException
                => (StatusCodes.Status500InternalServerError, "DB_ERROR", "Ocurrió un error al procesar la solicitud."),

            UnauthorizedAccessException
                => (StatusCodes.Status401Unauthorized, "UNAUTHORIZED", "No autorizado."),

            _ => (StatusCodes.Status500InternalServerError, "INTERNAL_ERROR", "Ocurrió un error inesperado.")
        };

        if (ex is PostgresException pg2 && !ApiErrorCatalog.Errors.ContainsKey(pg2.SqlState ?? ""))
            logger.LogError(ex, "PostgresException no catalogada [{SqlState}] en {Metodo} {Ruta}: {Mensaje}",
                pg2.SqlState, http.Request.Method, http.Request.Path, pg2.MessageText);
        else if (status >= 500)
            logger.LogError(ex, "Error no controlado en {Metodo} {Ruta}", http.Request.Method, http.Request.Path);
        else
            logger.LogWarning("[{Codigo}] {Mensaje} en {Metodo} {Ruta}", codigo, mensaje, http.Request.Method, http.Request.Path);

        http.Response.StatusCode = status;
        await http.Response.WriteAsJsonAsync(new { codigo, mensaje }, ct);
        return true;
    }
}
```

## Modules/Logs/Data/LogsRepository.cs

```csharp
using Npgsql;

namespace iet_bi_portal_backend.Modules.Logs.Data;

/// <summary>Acceso a la tabla api.logs. No conoce reglas de negocio de ningún otro módulo —
/// solo sabe insertar una entrada de auditoría vía api.fn_registrar_log.</summary>
public class LogsRepository
{
    private readonly NpgsqlDataSource _db;

    public LogsRepository(NpgsqlDataSource db) => _db = db;

    /// <summary> Inserta una entrada de auditoría. actorUserId es null para acciones del
    /// sistema/background. previousDataJson/newDataJson ya deben venir serializados (o null). </summary>
    public async Task<Guid> RegisterLogAsync(
        Guid? actorUserId,
        string action,
        string? affectedTable,
        string? affectedRecordId,
        string? previousDataJson,
        string? newDataJson,
        string? ip,
        string? userAgent)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT api.fn_registrar_log($1::uuid, $2::text, $3::text, $4::text, $5::jsonb, $6::jsonb, $7::text, $8::text)");

        cmd.Parameters.AddWithValue((object?)actorUserId ?? DBNull.Value);
        cmd.Parameters.AddWithValue(action);
        cmd.Parameters.AddWithValue((object?)affectedTable ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)affectedRecordId ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)previousDataJson ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)newDataJson ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)ip ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)userAgent ?? DBNull.Value);

        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id ? id : throw new InvalidOperationException("Respuesta inesperada de fn_registrar_log.");
    }
}
```

## Modules/Logs/LogsModule.cs

```csharp
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
```

## Modules/Logs/log_codes.md

```markdown
CREATE_USER       // Alta de un usuario por un administrador (siempre nace con PROFESOR_REGULAR).
LOGIN             // Inicio de sesión exitoso.
LOGOUT_ALL        // Cierre de todas las sesiones del usuario autenticado.
CHANGE_PASSWORD   // Cambio de contraseña por el propio usuario. Nunca se loguea el hash ni la contraseña.
RESET_PASSWORD    // Reseteo de contraseña de otro usuario por un administrador. Nunca se loguea el hash ni la contraseña.
BOOTSTRAP_ADMIN   // Creación del primer administrador del sistema.
ASSIGN_ROLE       // Se le otorgó un rol a un usuario (queda el rol en newData).
REVOKE_ROLE       // Se le quitó un rol a un usuario (queda el rol en previousData).
UPDATE_USER_EMAIL // Un administrador modificó el email de un usuario (queda el email nuevo en newData).
ACTIVATE_USER     // Un administrador reactivó a un usuario previamente desactivado.
DEACTIVATE_USER   // Un administrador desactivó a un usuario.
DELETE_USER       // Un administrador eliminó físicamente a un usuario (queda email+roles en previousData, snapshot previo al borrado).
LOGOUT            // Cierre de la sesión actual. El actor se obtiene del refresh token; si el token no existía no se registra.
CREATE_PROFESSOR  // Alta de perfil de profesor por un administrador (queda usuario + datos en newData).
UPDATE_PROFESSOR  // Modificación de un profesor (previousData = snapshot previo, newData = datos nuevos).
DELETE_PROFESSOR  // Eliminación del perfil de profesor (previousData = snapshot previo).
CREATE_STUDENT    // Alta de estudiante por un administrador.
UPDATE_STUDENT    // Modificación de un estudiante (previousData/newData).
DELETE_STUDENT    // Eliminación de un estudiante (previousData = snapshot previo).
```

## Modules/Logs/Services/LogsService.cs

```csharp
using System.Text.Json;
using iet_bi_portal_backend.Modules.Logs.Data;

namespace iet_bi_portal_backend.Modules.Logs.Services;

/// <summary>Servicio de auditoría. Cualquier módulo (Auth, Academico, lo que venga) lo
/// inyecta sin depender de cómo está implementado — solo de esta interfaz.</summary>
public interface ILogsService
{
    /// <summary> Registra una entrada de auditoría. actorUserId es null para acciones del
    /// sistema/background (jobs, background services). previousData/newData son objetos
    /// cualesquiera (se serializan a JSON acá adentro); pasar null si no aplica. </summary>
    Task RegisterLogAsync(
        Guid? actorUserId,
        string action,
        string? affectedTable = null,
        string? affectedRecordId = null,
        object? previousData = null,
        object? newData = null,
        string? ip = null,
        string? userAgent = null);
}

public class LogsService : ILogsService
{
    private readonly LogsRepository _repo;

    public LogsService(LogsRepository repo) => _repo = repo;

    public Task RegisterLogAsync(
        Guid? actorUserId,
        string action,
        string? affectedTable = null,
        string? affectedRecordId = null,
        object? previousData = null,
        object? newData = null,
        string? ip = null,
        string? userAgent = null) =>
        _repo.RegisterLogAsync(
            actorUserId,
            action,
            affectedTable,
            affectedRecordId,
            Serialize(previousData),
            Serialize(newData),
            ip,
            userAgent);

    private static string? Serialize(object? data) =>
        data is null ? null : JsonSerializer.Serialize(data);
}
```

## Modules/Professors/Controllers/AdminProfessorsController.cs

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Professors.Models;
using iet_bi_portal_backend.Modules.Professors.Services;

namespace iet_bi_portal_backend.Modules.Professors.Controllers;

[ApiController]
[Route("api/admin/professors")]
[Authorize(Roles = Roles.Admin)]
public class AdminProfessorsController : ControllerBase
{
    private readonly ProfessorsService _professors;

    public AdminProfessorsController(ProfessorsService professors) => _professors = professors;

    /// <summary>CU08: registra un profesor vinculado a un usuario existente. 201 con su id;
    /// 404 (NF001) si el usuario no existe; 409 (PR001) si ya tiene perfil; 409 (PR002) si la cédula está en uso.</summary>
    [HttpPost]
    public async Task<IActionResult> Register(RegisterProfessorRequest request)
    {
        if (User.GetUserId() is not { } actorId) return Unauthorized();

        var id = await _professors.RegisterAsync(actorId, request.IdUsuario!.Value, ProfessorInput.From(request));
        return StatusCode(StatusCodes.Status201Created, new { id });
    }

    /// <summary>CU09: lista profesores paginados.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] PaginationQuery query) =>
        Ok(await _professors.GetPagedAsync(query.Page, query.PageSize));

    /// <summary>CU09: detalle. 404 (NF002) si no existe.</summary>
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetById(long id)
    {
        var professor = await _professors.GetByIdAsync(id);
        return professor is null ? this.ApiError("NF002") : Ok(professor);
    }

    /// <summary>CU10: modifica un profesor (reemplazo completo de los campos editables).</summary>
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, UpdateProfessorRequest request)
    {
        if (User.GetUserId() is not { } actorId) return Unauthorized();

        await _professors.UpdateAsync(actorId, id, ProfessorInput.From(request));
        return NoContent();
    }

    /// <summary>CU11: elimina el perfil de profesor (el usuario se conserva).</summary>
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id)
    {
        if (User.GetUserId() is not { } actorId) return Unauthorized();

        await _professors.DeleteAsync(actorId, id);
        return NoContent();
    }
}
```

## Modules/Professors/Data/ProfessorsRepository.cs

```csharp
using System.Text.Json;
using Npgsql;
using iet_bi_portal_backend.Modules.Professors.Models;

namespace iet_bi_portal_backend.Modules.Professors.Data;

/// <summary>Acceso a las funciones de administración de profesores (CU08 a CU11).</summary>
public class ProfessorsRepository
{
    private const string Columns =
        "id_profesor, nombre, primer_apellido, segundo_apellido, cedula, numero_celular, fecha_nacimiento, id_usuario, email";

    private readonly NpgsqlDataSource _db;

    public ProfessorsRepository(NpgsqlDataSource db) => _db = db;

    /// <summary> Registra un profesor vinculado a un usuario existente. Lanza PostgresException si el actor
    /// no es ADMIN (AU009), el usuario no existe (NF001), ya tiene perfil (PR001) o la cédula está en uso (PR002). </summary>
    public async Task<long> RegisterAsync(Guid actorUserId, Guid userId, ProfessorInput input)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT academico.fn_registrar_profesor($1::uuid, $2::uuid, $3::text, $4::text, $5::text, $6::text, $7::text, $8::date)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(userId);
        AddInput(cmd, input);

        var result = await cmd.ExecuteScalarAsync();
        return result is long id ? id : throw new InvalidOperationException("Respuesta inesperada de fn_registrar_profesor.");
    }

    public async Task<(IReadOnlyList<ProfessorAdminRecord> Items, long TotalCount)> GetPagedAsync(int page, int pageSize)
    {
        var items = new List<ProfessorAdminRecord>();

        await using (var cmd = _db.CreateCommand($"SELECT {Columns} FROM academico.fn_listar_profesores_admin($1, $2)"))
        {
            cmd.Parameters.AddWithValue(page);
            cmd.Parameters.AddWithValue(pageSize);

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                items.Add(Read(reader));
        }

        await using var countCmd = _db.CreateCommand("SELECT academico.fn_contar_profesores_admin()");
        var total = await countCmd.ExecuteScalarAsync();

        return (items, total is long l ? l : 0);
    }

    public async Task<ProfessorAdminRecord?> GetByIdAsync(long id)
    {
        await using var cmd = _db.CreateCommand($"SELECT {Columns} FROM academico.fn_obtener_profesor_admin_por_id($1)");
        cmd.Parameters.AddWithValue(id);

        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Read(reader) : null;
    }

    /// <summary> Actualiza un profesor. Devuelve 'OK' o 'SIN_CAMBIOS' y, si hubo cambio, el snapshot previo
    /// (para auditoría). Lanza PostgresException: AU009, NF002 (no existe), PR002 (cédula en uso). </summary>
    public async Task<(string Status, JsonElement? Previous)> UpdateAsync(Guid actorUserId, long id, ProfessorInput input)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT out_status, out_datos_anteriores FROM academico.fn_admin_actualizar_profesor(" +
            "$1::uuid, $2::bigint, $3::text, $4::text, $5::text, $6::text, $7::text, $8::date)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(id);
        AddInput(cmd, input);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();

        var status = reader.GetString(0);
        JsonElement? previous = reader.IsDBNull(1) ? null : JsonSerializer.Deserialize<JsonElement>(reader.GetString(1));
        return (status, previous);
    }

    /// <summary> Elimina el perfil de profesor (el usuario se conserva). Devuelve el snapshot previo.
    /// Lanza PostgresException: AU009, NF002, o 23503 si otras entidades lo referencian. </summary>
    public async Task<JsonElement> DeleteAsync(Guid actorUserId, long id)
    {
        await using var cmd = _db.CreateCommand("SELECT academico.fn_admin_eliminar_profesor($1::uuid, $2::bigint)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(id);

        var result = await cmd.ExecuteScalarAsync();
        return result is string json
            ? JsonSerializer.Deserialize<JsonElement>(json)
            : throw new InvalidOperationException("Respuesta inesperada de fn_admin_eliminar_profesor.");
    }

    // Parámetros $3..$8 (nombre, apellidos, cédula, celular, fecha) para register y update.
    private static void AddInput(NpgsqlCommand cmd, ProfessorInput i)
    {
        cmd.Parameters.AddWithValue(i.Nombre);
        cmd.Parameters.AddWithValue(i.PrimerApellido);
        cmd.Parameters.AddWithValue((object?)i.SegundoApellido ?? DBNull.Value);
        cmd.Parameters.AddWithValue(i.Cedula);
        cmd.Parameters.AddWithValue((object?)i.NumeroCelular ?? DBNull.Value);
        cmd.Parameters.AddWithValue(i.FechaNacimiento);
    }

    private static ProfessorAdminRecord Read(NpgsqlDataReader r) => new(
        r.GetInt64(0),
        r.GetString(1),
        r.GetString(2),
        r.IsDBNull(3) ? null : r.GetString(3),
        r.GetString(4),
        r.IsDBNull(5) ? null : r.GetString(5),
        r.GetFieldValue<DateOnly>(6),
        r.GetGuid(7),
        r.GetString(8));
}
```

## Modules/Professors/Models/ProfessorModels.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Professors.Models;

/// <summary>Datos editables de un profesor (CU10). El usuario vinculado no se puede cambiar.</summary>
public class UpdateProfessorRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string Nombre { get; set; } = string.Empty;

    [Required, StringLength(100, MinimumLength = 2)]
    public string PrimerApellido { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? SegundoApellido { get; set; }

    [Required, StringLength(20, MinimumLength = 5)]
    public string Cedula { get; set; } = string.Empty;

    [MaxLength(20)]
    public string? NumeroCelular { get; set; }

    [Required]
    public DateOnly? FechaNacimiento { get; set; }
}

/// <summary>Datos para registrar un profesor (CU08): los mismos campos + el usuario existente al que se vincula.</summary>
public class RegisterProfessorRequest : UpdateProfessorRequest
{
    [Required]
    public Guid? IdUsuario { get; set; }
}

/// <summary>Datos ya normalizados (trim, vacíos a null) listos para la DB y para auditoría.</summary>
public record ProfessorInput(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    DateOnly FechaNacimiento)
{
    public static ProfessorInput From(UpdateProfessorRequest r) => new(
        r.Nombre.Trim(),
        r.PrimerApellido.Trim(),
        Clean(r.SegundoApellido),
        r.Cedula.Trim(),
        Clean(r.NumeroCelular),
        r.FechaNacimiento!.Value);

    private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}

/// <summary>Profesor tal como lo devuelven las funciones academico.fn_*_profesor*_admin. Se usa también como respuesta HTTP.</summary>
public record ProfessorAdminRecord(
    long Id,
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    DateOnly FechaNacimiento,
    Guid IdUsuario,
    string Email);
```

## Modules/Professors/ProfessorsModule.cs

```csharp
using iet_bi_portal_backend.Modules.Professors.Data;
using iet_bi_portal_backend.Modules.Professors.Services;

namespace iet_bi_portal_backend.Modules.Professors;

/// <summary>Administración de profesores. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class ProfessorsModule
{
    public static IServiceCollection AddProfessorsModule(this IServiceCollection services)
    {
        services.AddScoped<ProfessorsRepository>();
        services.AddScoped<ProfessorsService>();
        return services;
    }
}
```

## Modules/Professors/Services/ProfessorsService.cs

```csharp
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Professors.Data;
using iet_bi_portal_backend.Modules.Professors.Models;
using iet_bi_portal_backend.Modules.Users.Models;

namespace iet_bi_portal_backend.Modules.Professors.Services;

public class ProfessorsService
{
    private const string Table = "academico.profesores";

    private readonly ProfessorsRepository _repo;
    private readonly ILogsService _logs;

    public ProfessorsService(ProfessorsRepository repo, ILogsService logs)
    {
        _repo = repo;
        _logs = logs;
    }

    /// <summary>CU08: registra un profesor vinculado a un usuario existente. Reglas validadas por la DB.</summary>
    public async Task<long> RegisterAsync(Guid actorUserId, Guid userId, ProfessorInput input)
    {
        var id = await _repo.RegisterAsync(actorUserId, userId, input);

        await _logs.RegisterLogAsync(actorUserId, "CREATE_PROFESSOR", Table, id.ToString(),
            newData: new { idUsuario = userId, input });

        return id;
    }

    /// <summary>CU09: listado paginado.</summary>
    public async Task<PagedResult<ProfessorAdminRecord>> GetPagedAsync(int page, int pageSize)
    {
        var (items, total) = await _repo.GetPagedAsync(page, pageSize);
        return new PagedResult<ProfessorAdminRecord>(items, page, pageSize, total);
    }

    /// <summary>CU09: detalle, o null si no existe.</summary>
    public Task<ProfessorAdminRecord?> GetByIdAsync(long id) => _repo.GetByIdAsync(id);

    /// <summary>CU10: modifica un profesor. Loguea snapshot previo y datos nuevos solo si hubo cambios.</summary>
    public async Task<string> UpdateAsync(Guid actorUserId, long id, ProfessorInput input)
    {
        var (status, previous) = await _repo.UpdateAsync(actorUserId, id, input);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "UPDATE_PROFESSOR", Table, id.ToString(),
                previousData: previous, newData: input);

        return status;
    }

    /// <summary>CU11: elimina el perfil de profesor (el usuario se conserva).</summary>
    public async Task DeleteAsync(Guid actorUserId, long id)
    {
        var previous = await _repo.DeleteAsync(actorUserId, id);
        await _logs.RegisterLogAsync(actorUserId, "DELETE_PROFESSOR", Table, id.ToString(), previousData: previous);
    }
}
```

## Modules/Students/Controllers/AdminStudentsController.cs

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Common;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Students.Models;
using iet_bi_portal_backend.Modules.Students.Services;

namespace iet_bi_portal_backend.Modules.Students.Controllers;

[ApiController]
[Route("api/admin/students")]
[Authorize(Roles = Roles.Admin)]
public class AdminStudentsController : ControllerBase
{
    private readonly StudentsService _students;

    public AdminStudentsController(StudentsService students) => _students = students;

    /// <summary>CU12: registra un estudiante. 201 con su id; 409 (ES001/ES002) si cédula o correo están en uso;
    /// 400 (ES003) si no tiene entre 16 y 19 años.</summary>
    [HttpPost]
    public async Task<IActionResult> Register(StudentRequest request)
    {
        if (User.GetUserId() is not { } actorId) return Unauthorized();

        var id = await _students.RegisterAsync(actorId, StudentInput.From(request));
        return StatusCode(StatusCodes.Status201Created, new { id });
    }

    /// <summary>CU13: lista estudiantes paginados.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] PaginationQuery query) =>
        Ok(await _students.GetPagedAsync(query.Page, query.PageSize));

    /// <summary>CU13: detalle. 404 (NF003) si no existe.</summary>
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetById(long id)
    {
        var student = await _students.GetByIdAsync(id);
        return student is null ? this.ApiError("NF003") : Ok(student);
    }

    /// <summary>CU14: modifica un estudiante (reemplazo completo de los campos).</summary>
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, StudentRequest request)
    {
        if (User.GetUserId() is not { } actorId) return Unauthorized();

        await _students.UpdateAsync(actorId, id, StudentInput.From(request));
        return NoContent();
    }

    /// <summary>CU15: elimina un estudiante.</summary>
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id)
    {
        if (User.GetUserId() is not { } actorId) return Unauthorized();

        await _students.DeleteAsync(actorId, id);
        return NoContent();
    }
}
```

## Modules/Students/Data/StudentsRepository.cs

```csharp
using System.Text.Json;
using Npgsql;
using iet_bi_portal_backend.Modules.Students.Models;

namespace iet_bi_portal_backend.Modules.Students.Data;

/// <summary>Acceso a las funciones de administración de estudiantes (CU12 a CU15).</summary>
public class StudentsRepository
{
    private const string Columns =
        "id_estudiante, nombre, primer_apellido, segundo_apellido, cedula, numero_celular, email, fecha_nacimiento, fecha_registro";

    private readonly NpgsqlDataSource _db;

    public StudentsRepository(NpgsqlDataSource db) => _db = db;

    /// <summary> Registra un estudiante. Lanza PostgresException: AU009, ES001 (cédula), ES002 (correo), ES003 (edad). </summary>
    public async Task<long> RegisterAsync(Guid actorUserId, StudentInput input)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT academico.fn_registrar_estudiante($1::uuid, $2::text, $3::text, $4::text, $5::text, $6::text, $7::academico.citext, $8::date)");
        cmd.Parameters.AddWithValue(actorUserId);
        AddInput(cmd, input);

        var result = await cmd.ExecuteScalarAsync();
        return result is long id ? id : throw new InvalidOperationException("Respuesta inesperada de fn_registrar_estudiante.");
    }

    public async Task<(IReadOnlyList<StudentAdminRecord> Items, long TotalCount)> GetPagedAsync(int page, int pageSize)
    {
        var items = new List<StudentAdminRecord>();

        await using (var cmd = _db.CreateCommand($"SELECT {Columns} FROM academico.fn_listar_estudiantes_admin($1, $2)"))
        {
            cmd.Parameters.AddWithValue(page);
            cmd.Parameters.AddWithValue(pageSize);

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                items.Add(Read(reader));
        }

        await using var countCmd = _db.CreateCommand("SELECT academico.fn_contar_estudiantes_admin()");
        var total = await countCmd.ExecuteScalarAsync();

        return (items, total is long l ? l : 0);
    }

    public async Task<StudentAdminRecord?> GetByIdAsync(long id)
    {
        await using var cmd = _db.CreateCommand($"SELECT {Columns} FROM academico.fn_obtener_estudiante_admin_por_id($1)");
        cmd.Parameters.AddWithValue(id);

        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Read(reader) : null;
    }

    /// <summary> Actualiza un estudiante. Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo si hubo cambio.
    /// Lanza PostgresException: AU009, NF003, ES001, ES002, ES003 (solo si cambia la fecha de nacimiento). </summary>
    public async Task<(string Status, JsonElement? Previous)> UpdateAsync(Guid actorUserId, long id, StudentInput input)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT out_status, out_datos_anteriores FROM academico.fn_admin_actualizar_estudiante(" +
            "$1::uuid, $2::bigint, $3::text, $4::text, $5::text, $6::text, $7::text, $8::academico.citext, $9::date)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(id);
        AddInput(cmd, input);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();

        var status = reader.GetString(0);
        JsonElement? previous = reader.IsDBNull(1) ? null : JsonSerializer.Deserialize<JsonElement>(reader.GetString(1));
        return (status, previous);
    }

    /// <summary> Elimina un estudiante. Devuelve el snapshot previo. Lanza PostgresException: AU009, NF003,
    /// o 23503 si otras entidades lo referencian. </summary>
    public async Task<JsonElement> DeleteAsync(Guid actorUserId, long id)
    {
        await using var cmd = _db.CreateCommand("SELECT academico.fn_admin_eliminar_estudiante($1::uuid, $2::bigint)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(id);

        var result = await cmd.ExecuteScalarAsync();
        return result is string json
            ? JsonSerializer.Deserialize<JsonElement>(json)
            : throw new InvalidOperationException("Respuesta inesperada de fn_admin_eliminar_estudiante.");
    }

    // Parámetros en el orden nombre, apellido1, apellido2, cédula, celular, email, fecha.
    // Register los usa como $2..$8; Update como $3..$9 (el id va antes).
    private static void AddInput(NpgsqlCommand cmd, StudentInput i)
    {
        cmd.Parameters.AddWithValue(i.Nombre);
        cmd.Parameters.AddWithValue(i.PrimerApellido);
        cmd.Parameters.AddWithValue((object?)i.SegundoApellido ?? DBNull.Value);
        cmd.Parameters.AddWithValue(i.Cedula);
        cmd.Parameters.AddWithValue((object?)i.NumeroCelular ?? DBNull.Value);
        cmd.Parameters.AddWithValue(i.Email);
        cmd.Parameters.AddWithValue(i.FechaNacimiento);
    }

    private static StudentAdminRecord Read(NpgsqlDataReader r) => new(
        r.GetInt64(0),
        r.GetString(1),
        r.GetString(2),
        r.IsDBNull(3) ? null : r.GetString(3),
        r.GetString(4),
        r.IsDBNull(5) ? null : r.GetString(5),
        r.GetString(6),
        r.GetFieldValue<DateOnly>(7),
        r.GetDateTime(8));
}
```

## Modules/Students/Models/StudentModels.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Students.Models;

/// <summary>Datos para registrar (CU12) o modificar (CU14) un estudiante. La regla de edad 16-19 la valida la DB.</summary>
public class StudentRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string Nombre { get; set; } = string.Empty;

    [Required, StringLength(100, MinimumLength = 2)]
    public string PrimerApellido { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? SegundoApellido { get; set; }

    [Required, StringLength(20, MinimumLength = 5)]
    public string Cedula { get; set; } = string.Empty;

    [MaxLength(20)]
    public string? NumeroCelular { get; set; }

    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required]
    public DateOnly? FechaNacimiento { get; set; }
}

/// <summary>Datos ya normalizados (trim, vacíos a null, email en minúsculas).</summary>
public record StudentInput(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento)
{
    public static StudentInput From(StudentRequest r) => new(
        r.Nombre.Trim(),
        r.PrimerApellido.Trim(),
        Clean(r.SegundoApellido),
        r.Cedula.Trim(),
        Clean(r.NumeroCelular),
        r.Email.Trim().ToLowerInvariant(),
        r.FechaNacimiento!.Value);

    private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}

/// <summary>Estudiante tal como lo devuelven las funciones academico.fn_*_estudiante*_admin. Se usa también como respuesta HTTP.</summary>
public record StudentAdminRecord(
    long Id,
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento,
    DateTime FechaRegistro);
```

## Modules/Students/Services/StudentsService.cs

```csharp
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Students.Data;
using iet_bi_portal_backend.Modules.Students.Models;
using iet_bi_portal_backend.Modules.Users.Models;

namespace iet_bi_portal_backend.Modules.Students.Services;

public class StudentsService
{
    private const string Table = "academico.estudiantes";

    private readonly StudentsRepository _repo;
    private readonly ILogsService _logs;

    public StudentsService(StudentsRepository repo, ILogsService logs)
    {
        _repo = repo;
        _logs = logs;
    }

    /// <summary>CU12: registra un estudiante (edad 16-19 validada por la DB).</summary>
    public async Task<long> RegisterAsync(Guid actorUserId, StudentInput input)
    {
        var id = await _repo.RegisterAsync(actorUserId, input);
        await _logs.RegisterLogAsync(actorUserId, "CREATE_STUDENT", Table, id.ToString(), newData: input);
        return id;
    }

    /// <summary>CU13: listado paginado.</summary>
    public async Task<PagedResult<StudentAdminRecord>> GetPagedAsync(int page, int pageSize)
    {
        var (items, total) = await _repo.GetPagedAsync(page, pageSize);
        return new PagedResult<StudentAdminRecord>(items, page, pageSize, total);
    }

    /// <summary>CU13: detalle, o null si no existe.</summary>
    public Task<StudentAdminRecord?> GetByIdAsync(long id) => _repo.GetByIdAsync(id);

    /// <summary>CU14: modifica un estudiante. Loguea previo y nuevo solo si hubo cambios.</summary>
    public async Task<string> UpdateAsync(Guid actorUserId, long id, StudentInput input)
    {
        var (status, previous) = await _repo.UpdateAsync(actorUserId, id, input);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "UPDATE_STUDENT", Table, id.ToString(),
                previousData: previous, newData: input);

        return status;
    }

    /// <summary>CU15: elimina un estudiante.</summary>
    public async Task DeleteAsync(Guid actorUserId, long id)
    {
        var previous = await _repo.DeleteAsync(actorUserId, id);
        await _logs.RegisterLogAsync(actorUserId, "DELETE_STUDENT", Table, id.ToString(), previousData: previous);
    }
}
```

## Modules/Students/StudentsModule.cs

```csharp
using iet_bi_portal_backend.Modules.Students.Data;
using iet_bi_portal_backend.Modules.Students.Services;

namespace iet_bi_portal_backend.Modules.Students;

/// <summary>Administración de estudiantes. Requiere NpgsqlDataSource (DatabaseModule) e ILogsService (LogsModule).</summary>
public static class StudentsModule
{
    public static IServiceCollection AddStudentsModule(this IServiceCollection services)
    {
        services.AddScoped<StudentsRepository>();
        services.AddScoped<StudentsService>();
        return services;
    }
}
```

## Modules/Users/Controllers/AdminUsersController.cs

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Users.Models;
using iet_bi_portal_backend.Modules.Users.Services;

namespace iet_bi_portal_backend.Modules.Users.Controllers;

[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = Roles.Admin)]
public class AdminUsersController : ControllerBase
{
    private readonly UsersService _users;

    public AdminUsersController(UsersService users) => _users = users;

    /// <summary>CU02: registra un usuario nuevo con rol PROFESOR_REGULAR.
    /// Devuelve 201 Created con su id y email, o 409 Conflict (TA001) si el correo ya está en uso.</summary>
    [HttpPost]
    public async Task<IActionResult> Register(RegisterRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        var id = await _users.RegisterUserAsync(actorId.Value, request.Email, request.Password);
        return StatusCode(StatusCodes.Status201Created, new { id, email = request.Email.Trim().ToLowerInvariant() });
    }

    /// <summary>CU03: lista usuarios paginados, sin filtros (los aplica el frontend).</summary>
    [HttpGet]
    public async Task<IActionResult> GetUsers([FromQuery] ListUsersQuery query)
    {
        var result = await _users.GetUsersAsync(query.Page, query.PageSize);
        return Ok(result);
    }

    /// <summary>CU03: detalle de un usuario puntual. Devuelve 404 (NF001) si no existe.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetUser(Guid id)
    {
        var user = await _users.GetUserByIdAsync(id);
        return user is null ? this.ApiError("NF001") : Ok(user);
    }

    /// <summary>CU04: modifica el email de un usuario. Invalida sus sesiones (el JWT lleva el
    /// email como claim). Devuelve 409 (TA001) si el correo ya está en uso.</summary>
    [HttpPatch("{id:guid}/email")]
    public async Task<IActionResult> UpdateEmail(Guid id, UpdateEmailRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.UpdateEmailAsync(actorId.Value, id, request.Email);
        return NoContent();
    }

    /// <summary>CU04: resetea la contraseña de otro usuario. No requiere la contraseña actual:
    /// la autoridad es ser ADMIN. Cierra todas las sesiones del usuario objetivo.</summary>
    [HttpPost("{id:guid}/reset-password")]
    public async Task<IActionResult> ResetPassword(Guid id, ResetPasswordRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.ResetPasswordAsync(actorId.Value, id, request.NewPassword);
        return NoContent();
    }

    /// <summary>CU05: activa un usuario previamente desactivado.</summary>
    [HttpPost("{id:guid}/activate")]
    public async Task<IActionResult> Activate(Guid id)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.SetActiveAsync(actorId.Value, id, true);
        return NoContent();
    }

    /// <summary>CU05: desactiva un usuario. Falla (AU010) si un admin intenta desactivarse a
    /// sí mismo, o (AU011) si sería el último admin activo del sistema. Cierra todas sus
    /// sesiones e invalida sus tokens ya emitidos.</summary>
    [HttpPost("{id:guid}/deactivate")]
    public async Task<IActionResult> Deactivate(Guid id)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.SetActiveAsync(actorId.Value, id, false);
        return NoContent();
    }

    /// <summary>CU06: otorga un rol adicional. Los roles que ya tenía se conservan.</summary>
    [HttpPost("{id:guid}/roles")]
    public async Task<IActionResult> AssignRole(Guid id, RoleRequest request)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        var status = await _users.AssignRoleAsync(actorId.Value, id, request.Role);
        return status == "OK" ? StatusCode(StatusCodes.Status201Created) : NoContent();
    }

    /// <summary>CU06: quita un rol. Falla (AU005) si sería el último rol que le queda al usuario,
    /// o (AU003) si un ADMIN intenta quitarse a sí mismo el rol ADMIN.</summary>
    [HttpDelete("{id:guid}/roles/{role}")]
    public async Task<IActionResult> RevokeRole(Guid id, string role)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.RevokeRoleAsync(actorId.Value, id, role.ToUpperInvariant());
        return NoContent();
    }

    /// <summary>CU07: elimina físicamente un usuario. Falla (AU012) si un admin intenta
    /// eliminarse a sí mismo, o (AU013) si sería el último admin activo del sistema.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var actorId = User.GetUserId();
        if (actorId is null) return Unauthorized();

        await _users.DeleteUserAsync(actorId.Value, id);
        return NoContent();
    }
}
```

## Modules/Users/Data/UsersRepository.cs

```csharp
using Npgsql;
using iet_bi_portal_backend.Modules.Users.Models;

namespace iet_bi_portal_backend.Modules.Users.Data;

/// <summary>Acceso a las funciones de administración de usuarios: alta, consulta, edición
/// de email, reseteo de contraseña, activar/desactivar, asignar/revocar roles y eliminar.
/// Vive en Users, no en Auth: la gestión administrativa de usuarios no es autenticación.
/// Auth no sabe nada de esto.</summary>
public class UsersRepository
{
    private readonly NpgsqlDataSource _db;

    public UsersRepository(NpgsqlDataSource db) => _db = db;

    // ============================================================
    // CU 02 - Registrar usuarios
    // ============================================================

    /// <summary> Crea un usuario con rol PROFESOR_REGULAR. Lanza PostgresException si el
    /// actor no es ADMIN activo (AU009) o si el correo ya está en uso (TA001). </summary>
    public async Task<Guid> RegisterUserAsync(Guid actorUserId, string email, string passwordHash)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_registrar_usuario_admin($1, $2::academico.citext, $3)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(email);
        cmd.Parameters.AddWithValue(passwordHash);
        var result = await cmd.ExecuteScalarAsync();
        return result is Guid id ? id : throw new InvalidOperationException("Respuesta inesperada de fn_registrar_usuario_admin.");
    }

    // ============================================================
    // CU 03 - Consultar usuarios
    // ============================================================

    /// <summary> Lista usuarios paginados (sin filtros) y el total de usuarios en el sistema,
    /// para armar la metadata de paginación. Dos llamadas separadas: si se pide una página
    /// fuera de rango, el total sigue siendo correcto. </summary>
    public async Task<(IReadOnlyList<UserAdminRecord> Items, long TotalCount)> GetUsersPagedAsync(int page, int pageSize)
    {
        var items = new List<UserAdminRecord>();

        await using (var cmd = _db.CreateCommand(
            "SELECT id_usuario, email, activo, bloqueado_hasta, ultimo_login, creado_en, roles::text[], cantidad_sesiones " +
            "FROM auth.fn_listar_usuarios_admin($1, $2)"))
        {
            cmd.Parameters.AddWithValue(page);
            cmd.Parameters.AddWithValue(pageSize);

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                items.Add(ReadUserAdminRecord(reader));
        }

        await using var countCmd = _db.CreateCommand("SELECT auth.fn_contar_usuarios_admin()");
        var total = await countCmd.ExecuteScalarAsync();

        return (items, total is long l ? l : 0);
    }

    /// <summary> Obtiene el detalle de un usuario por su ID, o null si no existe. </summary>
    public async Task<UserAdminRecord?> GetUserByIdAsync(Guid id)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT id_usuario, email, activo, bloqueado_hasta, ultimo_login, creado_en, roles::text[], cantidad_sesiones " +
            "FROM auth.fn_obtener_usuario_admin_por_id($1)");
        cmd.Parameters.AddWithValue(id);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        return ReadUserAdminRecord(reader);
    }

    // ============================================================
    // CU 04 - Modificar usuarios (email) y resetear contraseña
    // ============================================================

    /// <summary> Actualiza el email de un usuario. Devuelve el estado ('OK' o 'SIN_CAMBIOS') y el
    /// email que tenía antes (para auditoría). Lanza PostgresException si el actor no es ADMIN (AU009),
    /// el objetivo no existe (NF001), o el correo ya está en uso (TA001). </summary>
    public async Task<(string Status, string PreviousEmail)> UpdateEmailAsync(Guid actorUserId, Guid targetUserId, string newEmail)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT out_status, out_email_anterior FROM auth.fn_admin_actualizar_email($1, $2, $3::academico.citext)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(newEmail);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();
        return (reader.GetString(0), reader.GetString(1));
    }

    /// <summary> Resetea la contraseña de un usuario (acción de administrador, sin conocer la
    /// contraseña actual). Invalida sesiones y tokens del usuario objetivo. </summary>
    public async Task ResetPasswordAsync(Guid actorUserId, Guid targetUserId, string newPasswordHash)
    {
        await using var cmd = _db.CreateCommand("CALL auth.sp_admin_resetear_contrasena($1, $2, $3)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(newPasswordHash);
        await cmd.ExecuteNonQueryAsync();
    }

    // ============================================================
    // CU 05 - Activar / desactivar usuarios
    // ============================================================

    /// <summary> Activa o desactiva un usuario. Devuelve 'OK' o 'SIN_CAMBIOS'; lanza
    /// PostgresException si el actor no es ADMIN (AU009), el objetivo no existe (NF001), si
    /// un admin intenta desactivarse a sí mismo (AU010), o si sería el último admin activo
    /// (AU011). Al desactivar, revoca sesiones e invalida tokens ya emitidos. </summary>
    public async Task<string> SetActiveAsync(Guid actorUserId, Guid targetUserId, bool activo)
    {
        await using var cmd = _db.CreateCommand("SELECT auth.fn_admin_cambiar_estado_usuario($1, $2, $3)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(activo);
        var result = await cmd.ExecuteScalarAsync();
        return result as string ?? throw new InvalidOperationException("Respuesta inesperada de fn_admin_cambiar_estado_usuario.");
    }

    // ============================================================
    // CU 06 - Asignar / revocar roles
    // ============================================================

    /// <summary> Otorga un rol adicional. Devuelve 'OK' o 'SIN_CAMBIOS'; lanza PostgresException si el actor no es ADMIN o el objetivo no existe. </summary>
    public Task<string> AssignRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        CallRoleFunctionAsync("auth.fn_asignar_rol", actorUserId, targetUserId, role);

    /// <summary> Quita un rol. Devuelve 'OK' o 'SIN_CAMBIOS'; lanza PostgresException si el actor no es ADMIN, el objetivo no existe, o sería el último rol del usuario. </summary>
    public Task<string> RevokeRoleAsync(Guid actorUserId, Guid targetUserId, string role) =>
        CallRoleFunctionAsync("auth.fn_revocar_rol", actorUserId, targetUserId, role);

    private async Task<string> CallRoleFunctionAsync(string function, Guid actorUserId, Guid targetUserId, string role)
    {
        await using var cmd = _db.CreateCommand($"SELECT {function}($1, $2, $3::api.roles)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);
        cmd.Parameters.AddWithValue(role);
        var result = await cmd.ExecuteScalarAsync();
        return result as string ?? throw new InvalidOperationException($"Respuesta inesperada de {function}.");
    }

    // ============================================================
    // CU 07 - Eliminar usuarios
    // ============================================================

    /// <summary> Elimina físicamente un usuario. Devuelve el email y los roles que tenía justo
    /// antes de borrarlo (para auditoría, ya que después del DELETE no queda nada que
    /// consultar). Lanza PostgresException si el actor no es ADMIN (AU009), el objetivo no
    /// existe (NF001), si un admin intenta eliminarse a sí mismo (AU012), o si sería el
    /// último admin activo (AU013). </summary>
    public async Task<(string Email, IReadOnlyList<string> Roles)> DeleteUserAsync(Guid actorUserId, Guid targetUserId)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT out_email, out_roles::text[] FROM auth.fn_admin_eliminar_usuario($1, $2)");
        cmd.Parameters.AddWithValue(actorUserId);
        cmd.Parameters.AddWithValue(targetUserId);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();

        var email = reader.GetString(0);
        var roles = reader.IsDBNull(1) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(1);
        return (email, roles);
    }

    private static UserAdminRecord ReadUserAdminRecord(NpgsqlDataReader reader) => new(
        reader.GetGuid(0),
        reader.GetString(1),
        reader.GetBoolean(2),
        reader.IsDBNull(3) ? null : reader.GetDateTime(3),
        reader.IsDBNull(4) ? null : reader.GetDateTime(4),
        reader.GetDateTime(5),
        reader.IsDBNull(6) ? Array.Empty<string>() : reader.GetFieldValue<string[]>(6),
        reader.GetInt64(7));
}
```

## Modules/Users/Models/ListUsersQuery.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Parámetros de paginación para el listado de usuarios (CU03). Sin filtros:
/// los aplica el frontend sobre el resultado, o se agregan más adelante si hace falta.</summary>
public class ListUsersQuery
{
    [Range(1, int.MaxValue, ErrorMessage = "La página debe ser mayor o igual a 1.")]
    public int Page { get; set; } = 1;

    [Range(1, 100, ErrorMessage = "El tamaño de página debe estar entre 1 y 100.")]
    public int PageSize { get; set; } = 20;
}
```

## Modules/Users/Models/PagedResult.cs

```csharp
namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Resultado paginado genérico. Se pensó para reutilizarse en otros listados
/// (ej. Estudiantes) que necesiten la misma forma de paginación.</summary>
public record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, long TotalCount);
```

## Modules/Users/Models/RegisterRequest.cs

```csharp

using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary> Datos para registrar un nuevo usuario. </summary>
public class RegisterRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}
```

## Modules/Users/Models/ResetPasswordRequest.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Datos para que un administrador resetee la contraseña de otro usuario (CU04).
/// A diferencia de ChangePasswordRequest (self-service), no requiere la contraseña actual:
/// la autoridad para esta acción es ser ADMIN, no conocer la contraseña vieja.</summary>
public class ResetPasswordRequest
{
    [Required, MinLength(8), MaxLength(128)]
    public string NewPassword { get; set; } = string.Empty;
}
```

## Modules/Users/Models/RoleRequest.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Datos para otorgar o revocar un rol a un usuario.</summary>
public class RoleRequest
{
    [Required, RegularExpression("^(ADMIN|PROFESOR_REGULAR|PROFESOR_CAS|GUIA|COORD_MONOGRAFIA|COORD_CAS)$",
        ErrorMessage = "Rol inválido. Valores permitidos: ADMIN, PROFESOR_REGULAR, PROFESOR_CAS, GUIA, COORD_MONOGRAFIA, COORD_CAS.")]
    public string Role { get; set; } = string.Empty;
}
```

## Modules/Users/Models/UpdateEmailRequest.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Datos para que un administrador modifique el email de otro usuario (CU04).</summary>
public class UpdateEmailRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;
}
```

## Modules/Users/Models/UserAdminRecord.cs

```csharp
namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Registro de usuario tal como lo devuelve auth.fn_listar_usuarios_admin /
/// auth.fn_obtener_usuario_admin_por_id. Nunca incluye password_hash: el módulo Users no
/// necesita conocerlo para nada de lo que hace.</summary>
public record UserAdminRecord(
    Guid Id,
    string Email,
    bool Activo,
    DateTime? BloqueadoHasta,
    DateTime? UltimoLogin,
    DateTime CreadoEn,
    IReadOnlyList<string> Roles,
    long CantidadSesiones);

/// <summary>Forma de respuesta HTTP para el detalle/listado de usuarios (CU03).</summary>
public record UserAdminResponse(
    Guid Id,
    string Email,
    bool Activo,
    DateTime? BloqueadoHasta,
    DateTime? UltimoLogin,
    DateTime CreadoEn,
    IReadOnlyList<string> Roles,
    long CantidadSesiones);
```

## Modules/Users/Services/UsersService.cs

```csharp
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Logs.Services;
using iet_bi_portal_backend.Modules.Users.Data;
using iet_bi_portal_backend.Modules.Users.Models;
using iet_bi_portal_backend.Security;

namespace iet_bi_portal_backend.Modules.Users.Services;

public class UsersService
{
    private readonly UsersRepository _repo;
    private readonly ILogsService _logs;
    private readonly IPasswordService _passwords;

    public UsersService(UsersRepository repo, ILogsService logs, IPasswordService passwords)
    {
        _repo = repo;
        _logs = logs;
        _passwords = passwords;
    }

    /// <summary>CU02: registra un usuario nuevo con rol PROFESOR_REGULAR. Requiere que el
    /// actor sea ADMIN activo (lo valida la DB, AU009/TA001). No emite sesión: el admin no
    /// recibe tokens del usuario creado.</summary>
    public async Task<Guid> RegisterUserAsync(Guid actorUserId, string email, string password)
    {
        email = NormalizeEmail(email);
        var userId = await _repo.RegisterUserAsync(actorUserId, email, _passwords.Hash(password));

        await _logs.RegisterLogAsync(actorUserId, "CREATE_USER", "api.usuarios", userId.ToString(),
            newData: new { email, roles = new[] { Roles.ProfesorRegular } });

        return userId;
    }

    /// <summary>CU03: lista usuarios paginados, sin filtros (los aplica el frontend).</summary>
    public async Task<PagedResult<UserAdminResponse>> GetUsersAsync(int page, int pageSize)
    {
        var (items, total) = await _repo.GetUsersPagedAsync(page, pageSize);
        return new PagedResult<UserAdminResponse>(items.Select(MapToResponse).ToList(), page, pageSize, total);
    }

    /// <summary>CU03: detalle de un usuario puntual, o null si no existe.</summary>
    public async Task<UserAdminResponse?> GetUserByIdAsync(Guid id)
    {
        var record = await _repo.GetUserByIdAsync(id);
        return record is null ? null : MapToResponse(record);
    }

    public async Task<string> UpdateEmailAsync(Guid actorUserId, Guid targetUserId, string newEmail)
    {
        newEmail = NormalizeEmail(newEmail);
        var (status, previousEmail) = await _repo.UpdateEmailAsync(actorUserId, targetUserId, newEmail);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "UPDATE_USER_EMAIL", "api.usuarios", targetUserId.ToString(),
                previousData: new { email = previousEmail },
                newData: new { email = newEmail });

        return status;
    }

    /// <summary>CU04: resetea la contraseña de otro usuario (acción de administrador, no
    /// requiere la contraseña actual). Nunca se loguea el hash ni la contraseña en sí.</summary>
    public async Task ResetPasswordAsync(Guid actorUserId, Guid targetUserId, string newPassword)
    {
        await _repo.ResetPasswordAsync(actorUserId, targetUserId, _passwords.Hash(newPassword));
        await _logs.RegisterLogAsync(actorUserId, "RESET_PASSWORD", "api.usuarios", targetUserId.ToString());
    }

    /// <summary>CU05: activa o desactiva un usuario. No permite auto-desactivación ni dejar
    /// el sistema sin ningún admin activo (lo valida la DB, AU010/AU011).</summary>
    public async Task<string> SetActiveAsync(Guid actorUserId, Guid targetUserId, bool activo)
    {
        var status = await _repo.SetActiveAsync(actorUserId, targetUserId, activo);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, activo ? "ACTIVATE_USER" : "DEACTIVATE_USER",
                "api.usuarios", targetUserId.ToString());

        return status;
    }

    /// <summary>CU06: otorga un rol. Requiere que el actor sea ADMIN activo (lo valida la DB, AU002/NF001).</summary>
    public async Task<string> AssignRoleAsync(Guid actorUserId, Guid targetUserId, string role)
    {
        var status = await _repo.AssignRoleAsync(actorUserId, targetUserId, role);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "ASSIGN_ROLE", "api.usuario_roles", targetUserId.ToString(),
                newData: new { rol = role });

        return status;
    }

    /// <summary>CU06: quita un rol. No permite dejar al usuario sin roles (AU002/NF001/AU003/AU004/AU005).</summary>
    public async Task<string> RevokeRoleAsync(Guid actorUserId, Guid targetUserId, string role)
    {
        var status = await _repo.RevokeRoleAsync(actorUserId, targetUserId, role);

        if (status == "OK")
            await _logs.RegisterLogAsync(actorUserId, "REVOKE_ROLE", "api.usuario_roles", targetUserId.ToString(),
                previousData: new { rol = role });

        return status;
    }

    /// <summary>CU07: elimina físicamente un usuario. No permite auto-eliminación ni dejar el
    /// sistema sin ningún admin activo (lo valida la DB, AU012/AU013). Loguea el email y los
    /// roles que tenía justo antes de borrarlo, porque después del DELETE ya no hay nada
    /// que consultar.</summary>
    public async Task DeleteUserAsync(Guid actorUserId, Guid targetUserId)
    {
        var (email, roles) = await _repo.DeleteUserAsync(actorUserId, targetUserId);

        await _logs.RegisterLogAsync(actorUserId, "DELETE_USER", "api.usuarios", targetUserId.ToString(),
            previousData: new { email, roles });
    }

    private static UserAdminResponse MapToResponse(UserAdminRecord r) => new(
        r.Id, r.Email, r.Activo, r.BloqueadoHasta, r.UltimoLogin, r.CreadoEn, r.Roles, r.CantidadSesiones);

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();
}
```

## Modules/Users/UsersModule.cs

```csharp
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
```

# Project Structure

```
Resources/
└── sql
    ├── 01_roles_schemas.sql
    ├── 02_auth.sql
    ├── 03_logs.sql
    ├── 04_admin_usuarios.sql
    ├── 05_db.sql
    ├── 06_admin_profesores.sql
    ├── 07_admin_estudiantes.sql
    └── views.sql
```

# File Contents

## Resources/sql/01_roles_schemas.sql

```sql
-- ============================================================
-- ROLES, ESQUEMAS Y PERMISOS INICIALES
-- Para el server de la UCR ejecutar solo el primer bloque de codigo, para localhost ejecutar todo el script (quitar el FALSE).
-- ============================================================
BEGIN;
    -- ============================================================
    -- 1. CREAR ESQUEMAS
    -- ============================================================
    DROP SCHEMA IF EXISTS academico CASCADE;
    DROP SCHEMA IF EXISTS api CASCADE;
    DROP SCHEMA IF EXISTS auth CASCADE;

    CREATE SCHEMA academico;
    CREATE SCHEMA api;
    CREATE SCHEMA auth;

    -- ============================================================
    -- 2. EXTENSIONES
    -- ============================================================
    CREATE EXTENSION IF NOT EXISTS citext SCHEMA academico;
    CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA academico;
    CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA academico;

    -- ============================================================
    -- 3. SEARCH PATH DE INSTALACIÓN
    -- ============================================================
    SET search_path = academico, auth, api, public, pg_catalog;
COMMIT;

BEGIN;
-- ============================================================
-- 3. CREAR ROLES
-- ============================================================
DO $$
BEGIN
    IF (FALSE) THEN
        -- Rol de administración
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_admin') THEN
            CREATE ROLE bi_admin NOLOGIN;
        END IF;

        -- Rol utilizado por el API
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_api') THEN
            CREATE ROLE bi_api NOLOGIN;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_admin') THEN
            CREATE ROLE svc_admin LOGIN PASSWORD '1234';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_api') THEN
            CREATE ROLE svc_api LOGIN PASSWORD '1234';
        END IF;

        -- Herencia de permisos
        GRANT bi_admin TO svc_admin;
        GRANT bi_api TO svc_api;

        -- Descripciones
        COMMENT ON ROLE svc_admin IS 'Cuenta de conexión del backoffice/administración.';
        COMMENT ON ROLE svc_api IS 'Cuenta de conexión utilizada por el API.';

        -- ============================================================
        -- 4. SEGURIDAD DE LOS ESQUEMAS
        -- ============================================================
        REVOKE ALL ON SCHEMA academico FROM PUBLIC;
        REVOKE ALL ON SCHEMA api FROM PUBLIC;
        REVOKE ALL ON SCHEMA auth FROM PUBLIC;

        -- ============================================================
        -- 5. ACCESO A LOS ESQUEMAS PARA EL API
        -- ============================================================
        GRANT USAGE ON SCHEMA academico TO bi_api;
        GRANT USAGE ON SCHEMA api TO bi_api;
        GRANT USAGE ON SCHEMA auth TO bi_api;

        -- ============================================================
        -- 6. PERMISOS SOBRE ACADEMICO
        -- ============================================================
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA academico TO bi_api;
        GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA academico TO bi_api;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA academico TO bi_api;
        GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA academico TO bi_api;

        -- ============================================================
        -- 7. PERMISOS SOBRE API
        -- ============================================================
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA api TO bi_api;
        GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA api TO bi_api;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO bi_api;
        GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA api TO bi_api;

        -- ============================================================
        -- 8. PERMISOS SOBRE AUTH
        -- ============================================================
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth TO bi_api;
        GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA auth TO bi_api;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO bi_api;
        GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA auth TO bi_api;

        -- ============================================================
        -- 9. PRIVILEGIOS POR DEFECTO
        -- ============================================================
        -- ACADEMICO
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT EXECUTE ON FUNCTIONS TO bi_api;

        -- API
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT EXECUTE ON FUNCTIONS TO bi_api;

        -- AUTH
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT EXECUTE ON FUNCTIONS TO bi_api;

        -- ============================================================
        -- 10. EVITAR EJECUCIÓN DE FUNCIONES POR PUBLIC
        -- ============================================================
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
    END IF;
END;
$$;
COMMIT;




```

## Resources/sql/02_auth.sql

```sql
SET search_path = academico, api, auth, public;
-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE api.roles AS ENUM (
    'ADMIN',
    'PROFESOR_REGULAR',
    'PROFESOR_CAS',
    'GUIA',
    'COORD_MONOGRAFIA',
    'COORD_CAS'
);

-- ============================================================
-- PUBLIC TYPES
-- ============================================================
CREATE TYPE api.usuario AS (
    id_usuario UUID,
    email CITEXT,
    password_hash TEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    roles api.roles[]
);

CREATE TYPE api.rotate_session_result AS (
    out_status TEXT,
    out_user_id UUID,
    out_email CITEXT, 
    out_roles api.roles[]
);

-- ============================================================
-- FUNCIONES AUXILIARES
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_lanzar_excepcion(
    p_codigo TEXT,
    p_mensaje TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = p_codigo, MESSAGE = p_mensaje;
END;
$$;

-- ============================================================
-- TABLAS
-- ============================================================
-- USUARIOS
CREATE TABLE api.usuarios (
    id_usuario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email CITEXT NOT NULL,
    password_hash TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    intentos_fallidos_login INTEGER NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMPTZ NULL,
    ultimo_login TIMESTAMPTZ NULL,
    password_cambiada_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tokens_invalidados_desde TIMESTAMPTZ NULL,
    CONSTRAINT ck_usuarios_password_hash_not_empty CHECK (trim(password_hash) <> ''),
    CONSTRAINT uq_usuarios_email UNIQUE (email),
    CONSTRAINT ck_usuarios_email_length CHECK (length(email) BETWEEN 3 AND 254),
    CONSTRAINT ck_usuarios_intentos_fallidos CHECK (intentos_fallidos_login >= 0),
    CONSTRAINT ck_usuarios_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ROLES DE USUARIO
CREATE TABLE api.usuario_roles (
    id_usuario UUID NOT NULL,
    rol api.roles NOT NULL,
    asignado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    asignado_por UUID NULL,
    CONSTRAINT pk_usuario_roles PRIMARY KEY (id_usuario, rol),
    CONSTRAINT fk_usuario_roles_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_usuario_roles_asignado_por FOREIGN KEY (asignado_por) REFERENCES api.usuarios (id_usuario) ON DELETE SET NULL
);
CREATE INDEX ix_usuario_roles_rol ON api.usuario_roles (rol);

-- SESIONES
CREATE TABLE api.sesiones (
    id_sesion UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL,
    token_hash TEXT NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_en TIMESTAMPTZ NOT NULL,
    rotado_en TIMESTAMPTZ NULL,
    direccion_ip TEXT NULL,
    agente_usuario TEXT NULL,
    CONSTRAINT fk_sesiones_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT ck_sesiones_expiracion CHECK (expira_en > creado_en)
);
CREATE UNIQUE INDEX ux_sesiones_token_hash ON api.sesiones (token_hash);
CREATE INDEX ix_sesiones_user_id ON api.sesiones (id_usuario);
CREATE INDEX ix_sesiones_expira_en ON api.sesiones (expira_en);

-- BOOTSTRAP ADMIN
CREATE TABLE IF NOT EXISTS api.bootstrap_admin (
    id_bootstrap INTEGER PRIMARY KEY,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario UUID NOT NULL,
    CONSTRAINT fk_bootstrap_admin_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario)
);

-- ============================================================
-- FUNCIONES DE BOOTSTRAP
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_crear_primer_admin(
    p_email CITEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_usuario UUID;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('api.bootstrap_admin', 0));

    IF EXISTS (SELECT 1 FROM api.bootstrap_admin) THEN
        PERFORM auth.fn_lanzar_excepcion('AU001', 'El administrador inicial ya fue creado.');
    END IF;
    
    IF p_email IS NULL OR trim(p_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF EXISTS (SELECT 1 FROM api.usuarios WHERE email = trim(p_email::TEXT)::CITEXT) THEN
        PERFORM auth.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    IF p_password_hash IS NULL OR trim(p_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash, activo)
    VALUES (trim(p_email::TEXT)::CITEXT, p_password_hash, TRUE)
    RETURNING id_usuario INTO v_id_usuario;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (v_id_usuario, 'ADMIN', NULL);

    INSERT INTO api.bootstrap_admin (id_bootstrap, id_usuario)
    VALUES (1, v_id_usuario);

    RETURN v_id_usuario;
END;
$$;

-- ============================================================
-- FUNCIONES DE AUTENTICACIÓN
-- ============================================================
-- Registrar usuario. Devuelve el id nuevo, o NULL si el correo ya existe.
CREATE OR REPLACE FUNCTION auth.fn_registrar_usuario(
    p_email CITEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF p_email IS NULL OR trim(p_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF p_password_hash IS NULL OR trim(p_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash)
    VALUES (trim(p_email::TEXT)::CITEXT, p_password_hash)
    ON CONFLICT (email) DO NOTHING
    RETURNING id_usuario
    INTO v_id;

    IF v_id IS NOT NULL THEN
        INSERT INTO api.usuario_roles (id_usuario, rol)
        VALUES (v_id, 'PROFESOR_REGULAR');
    END IF;

    RETURN v_id;
END;
$$;

-- Obtener usuario por email. Devuelve 0 filas si no existe.
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_email(
    p_email CITEXT
)
RETURNS SETOF api.usuario
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta,
        COALESCE(
            array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL),
            ARRAY[]::api.roles[]
        )
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur
        ON ur.id_usuario = u.id_usuario
    WHERE u.email = trim(p_email::TEXT)::CITEXT
    GROUP BY
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta;
END;
$$;

-- Obtener usuario por ID. Devuelve 0 filas si no existe.
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_id(
    p_id_usuario UUID
)
RETURNS SETOF api.usuario
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta,
        COALESCE(
            array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL),
            ARRAY[]::api.roles[]
        )
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur
        ON ur.id_usuario = u.id_usuario
    WHERE u.id_usuario = p_id_usuario
    GROUP BY
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta;
END;
$$;

-- Renovar sesión (rotación de refresh token). Todo ocurre dentro de la transacción de la función.
-- out_status:
--   'ok'       -> token válido; se marcó como usado y se creó uno nuevo
--   'invalid'  -> no existe / usuario inactivo
--   'expired'  -> el token expiró
--   'reused'   -> se intentó usar un token ya usado.
--                 Se cierran todas las sesiones del usuario y
--                 se invalidan los access tokens emitidos.
CREATE OR REPLACE FUNCTION auth.fn_rotar_sesion(
    p_old_token_hash TEXT,
    p_new_token_hash TEXT,
    p_new_expires_at TIMESTAMPTZ,
    p_direccion_ip TEXT,
    p_agente_usuario TEXT
)
RETURNS SETOF api.rotate_session_result
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_sesion api.sesiones%ROWTYPE;
    v_usuario api.usuarios%ROWTYPE;
    v_roles api.roles[];
BEGIN
    -- Buscar y bloquear el refresh token.
    SELECT *
    INTO v_sesion
    FROM api.sesiones s
    WHERE s.token_hash = p_old_token_hash
    FOR UPDATE;

    -- Token inexistente.
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            'invalid'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- El token ya fue utilizado.
    -- Posible reutilización/robo del refresh token.
    IF v_sesion.rotado_en IS NOT NULL THEN
        -- Revocar todos los refresh tokens del usuario.
        DELETE FROM api.sesiones
        WHERE id_usuario = v_sesion.id_usuario;

        -- Invalidar los access tokens emitidos anteriormente.
        UPDATE api.usuarios
        SET tokens_invalidados_desde = NOW()
        WHERE id_usuario = v_sesion.id_usuario;

        RETURN QUERY
        SELECT
            'reused'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- Token expirado.
    IF v_sesion.expira_en <= NOW() THEN
        RETURN QUERY
        SELECT
            'expired'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- Obtener usuario.
    SELECT *
    INTO v_usuario
    FROM api.usuarios u
    WHERE u.id_usuario = v_sesion.id_usuario;

    -- Usuario inexistente o inactivo.
    IF NOT FOUND OR NOT v_usuario.activo THEN
        RETURN QUERY
        SELECT
            'invalid'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- Obtener roles.
    SELECT COALESCE(
        array_agg(ur.rol),
        ARRAY[]::api.roles[]
    )
    INTO v_roles
    FROM api.usuario_roles ur
    WHERE ur.id_usuario = v_usuario.id_usuario;

    -- Marcar el refresh token anterior como rotado.
    UPDATE api.sesiones
    SET rotado_en = NOW()
    WHERE id_sesion = v_sesion.id_sesion;

    -- Crear el nuevo refresh token.
    INSERT INTO api.sesiones (
        id_usuario,
        token_hash,
        expira_en,
        direccion_ip,
        agente_usuario
    )
    VALUES (
        v_sesion.id_usuario,
        p_new_token_hash,
        p_new_expires_at,
        p_direccion_ip,
        p_agente_usuario
    );

    -- Éxito.
    RETURN QUERY
    SELECT
        'ok'::TEXT,
        v_usuario.id_usuario,
        v_usuario.email,
        v_roles;
END;
$$;

-- Asignar rol. No reemplaza los roles existentes.
CREATE OR REPLACE FUNCTION auth.fn_asignar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
BEGIN
    -- El actor debe ser un administrador activo.
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur
            ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU002', 'No tienes permisos para modificar roles.');
    END IF;

    -- El usuario objetivo debe existir.
    IF NOT EXISTS (
        SELECT 1
        FROM api.usuarios
        WHERE id_usuario = p_id_usuario_objetivo
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario objetivo no existe.');
    END IF;

    -- Asignar el rol si todavía no lo tiene.
    INSERT INTO api.usuario_roles (
        id_usuario,
        rol,
        asignado_por
    )
    VALUES (
        p_id_usuario_objetivo,
        p_rol,
        p_id_usuario_actor
    )
    ON CONFLICT (id_usuario, rol) DO NOTHING;

    -- El rol ya existía.
    IF NOT FOUND THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    -- Cambio de roles: revocar sesiones y tokens ya emitidos.
    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario_objetivo;

    UPDATE api.usuarios
    SET tokens_invalidados_desde = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    RETURN 'OK';
END;
$$;

-- ============================================================
-- Revoca un rol.
-- Reglas:
--   1. El actor debe ser un administrador activo.
--   2. El usuario objetivo debe existir.
--   3. El usuario debe tener el rol que se quiere revocar.
--   4. El usuario no puede quedarse sin roles.
--   5. Un administrador no puede quitarse a sí mismo el rol ADMIN.
--   6. No se puede eliminar el último ADMIN del sistema.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_revocar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_cantidad_roles INTEGER;
    v_cantidad_admins INTEGER;
BEGIN
    -- 1. El actor debe ser un administrador activo.
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur
            ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU002', 'No tienes permisos para modificar roles.');
    END IF;

    -- 2. El usuario objetivo debe existir.
    IF NOT EXISTS (
        SELECT 1
        FROM api.usuarios
        WHERE id_usuario = p_id_usuario_objetivo
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario objetivo no existe.');
    END IF;

    -- 3. Comprobar que el usuario tenga el rol.
    IF NOT EXISTS (
        SELECT 1
        FROM api.usuario_roles
        WHERE id_usuario = p_id_usuario_objetivo
            AND rol = p_rol
    ) THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    -- 4. Un ADMIN no puede quitarse a sí mismo el ADMIN.
    IF p_rol = 'ADMIN'
        AND p_id_usuario_actor = p_id_usuario_objetivo THEN
        PERFORM auth.fn_lanzar_excepcion('AU003', 'Un administrador no puede quitarse a sí mismo el rol ADMIN.');
    END IF;

    -- 5. No eliminar el último ADMIN del sistema.
    IF p_rol = 'ADMIN' THEN
        SELECT COUNT(*)
        INTO v_cantidad_admins
        FROM api.usuario_roles ur
        JOIN api.usuarios u
            ON u.id_usuario = ur.id_usuario
        WHERE ur.rol = 'ADMIN'
          AND u.activo = TRUE;
        IF v_cantidad_admins <= 1 THEN
            PERFORM auth.fn_lanzar_excepcion('AU004', 'No se puede revocar el último administrador activo del sistema.');
        END IF;
    END IF;

    -- 6. Contar roles actuales del usuario.
    SELECT COUNT(*)
    INTO v_cantidad_roles
    FROM api.usuario_roles
    WHERE id_usuario = p_id_usuario_objetivo;

    -- 7. No permitir que el usuario quede sin ningún rol.
    IF v_cantidad_roles <= 1 THEN
        PERFORM auth.fn_lanzar_excepcion('AU005', 'No se puede quitar el único rol que tiene el usuario.');
    END IF;

    -- 8. Revocar el rol.
    DELETE FROM api.usuario_roles
    WHERE id_usuario = p_id_usuario_objetivo
        AND rol = p_rol;

    -- 9. Revocar sesiones y tokens existentes.
    -- TODO: esto podria ser una funcion aparte, pero por ahora lo dejamos aquí.
    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario_objetivo;

    UPDATE api.usuarios
    SET tokens_invalidados_desde = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    RETURN 'OK';
END;
$$;

-- Login fallido: suma un intento; al llegar al máximo bloquea la cuenta.
CREATE OR REPLACE PROCEDURE auth.sp_registrar_login_fallido(
    p_id_usuario UUID,
    p_intentos_maximos INTEGER,
    p_minutos_bloqueo INTEGER
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    UPDATE api.usuarios
    SET
        bloqueado_hasta =
            CASE
                WHEN intentos_fallidos_login + 1 >= p_intentos_maximos
                     AND (
                         bloqueado_hasta IS NULL
                         OR bloqueado_hasta <= NOW()
                     )
                THEN NOW() + make_interval(mins => p_minutos_bloqueo)

                ELSE bloqueado_hasta
            END,
        intentos_fallidos_login =
            CASE
                WHEN intentos_fallidos_login + 1 >= p_intentos_maximos
                     AND (
                         bloqueado_hasta IS NULL
                         OR bloqueado_hasta <= NOW()
                     )
                THEN 0

                ELSE intentos_fallidos_login + 1
            END,
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;
END;
$$;

-- Login exitoso: limpia contadores y registra la fecha
CREATE OR REPLACE PROCEDURE auth.sp_registrar_login_exitoso(
    p_id_usuario UUID
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    UPDATE api.usuarios
    SET intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        ultimo_login = NOW(),
        actualizado_en  = NOW()
    WHERE id_usuario = p_id_usuario;
END;
$$;

-- Crear sesión (guarda el hash del refresh token)
CREATE OR REPLACE PROCEDURE auth.sp_crear_sesion(
    p_id_usuario UUID,
    p_token_hash TEXT,
    p_expira_en TIMESTAMPTZ,
    p_direccion_ip TEXT,
    p_agente_usuario TEXT
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    INSERT INTO api.sesiones (
        id_usuario, 
        token_hash, 
        expira_en, 
        direccion_ip, 
        agente_usuario
    ) VALUES (
        p_id_usuario, 
        p_token_hash,
        p_expira_en,
        p_direccion_ip, 
        p_agente_usuario
    );
END;
$$;

-- Logout (esta sesión). Devuelve el id del usuario dueño de la sesión, o NULL si el token no existía.
CREATE OR REPLACE FUNCTION auth.fn_logout(
    p_token_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_usuario UUID;
BEGIN
    DELETE FROM api.sesiones
    WHERE token_hash = p_token_hash
    RETURNING id_usuario INTO v_id_usuario;

    RETURN v_id_usuario;
END;
$$;

-- Logout global (todas las sesiones)
CREATE OR REPLACE PROCEDURE auth.sp_logout_all(
    p_id_usuario UUID
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    UPDATE api.usuarios
    SET tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;

    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario;
END;
$$;

CREATE OR REPLACE PROCEDURE auth.sp_cambiar_contrasena(
    p_id_usuario UUID,
    p_new_password_hash TEXT
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario objetivo no existe.');
    END IF;

    IF p_new_password_hash IS NULL
       OR trim(p_new_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    UPDATE api.usuarios
    SET
        password_hash = p_new_password_hash,
        password_cambiada_en = NOW(),
        intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;

    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario;
END;
$$;

-- Elimina las sesiones (refresh tokens) ya expiradas. La corre SessionCleanupService cada 24hs.
CREATE OR REPLACE PROCEDURE auth.sp_purgar_sesiones_expiradas()
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    DELETE FROM api.sesiones
    WHERE expira_en <= NOW();
END;
$$;
```

## Resources/sql/03_logs.sql

```sql
SET search_path = academico, api, auth, public;

-- ============================================================
-- TABLAS
-- ============================================================
-- LOGS
CREATE TABLE api.logs (
    id_log UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NULL,                    -- quién lo hizo (NULL = sistema/background)
    accion TEXT NOT NULL,                     -- 'LOGIN', 'ASSIGN_ROLE', 'UPDATE', etc.
    tabla_afectada TEXT NULL,                 -- 'api.usuario_roles', si aplica
    id_registro_afectado TEXT NULL,           -- PK de la fila afectada, como texto
    datos_anteriores JSONB NULL,              -- estado previo (UPDATE/DELETE)
    datos_nuevos JSONB NULL,                  -- estado nuevo (INSERT/UPDATE)
    direccion_ip TEXT NULL,
    agente_usuario TEXT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_logs_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario) ON DELETE SET NULL,
    CONSTRAINT ck_logs_accion_not_empty CHECK (trim(accion) <> '')
);

CREATE INDEX ix_logs_usuario ON api.logs (id_usuario);
CREATE INDEX ix_logs_creado_en ON api.logs (creado_en DESC);
CREATE INDEX ix_logs_accion ON api.logs (accion);

-- ============================================================
-- FUNCIONES DE LOGS
-- ============================================================
CREATE OR REPLACE FUNCTION api.fn_registrar_log(
    p_id_usuario UUID,
    p_accion TEXT,
    p_tabla_afectada TEXT DEFAULT NULL,
    p_id_registro_afectado TEXT DEFAULT NULL,
    p_datos_anteriores JSONB DEFAULT NULL,
    p_datos_nuevos JSONB DEFAULT NULL,
    p_direccion_ip TEXT DEFAULT NULL,
    p_agente_usuario TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_log UUID;
BEGIN
    INSERT INTO api.logs (
        id_usuario, accion, tabla_afectada, id_registro_afectado,
        datos_anteriores, datos_nuevos, direccion_ip, agente_usuario
    )
    VALUES (
        p_id_usuario, upper(trim(p_accion)), p_tabla_afectada, p_id_registro_afectado,
        p_datos_anteriores, p_datos_nuevos, p_direccion_ip, p_agente_usuario
    )
    RETURNING id_log INTO v_id_log;

    RETURN v_id_log;
END;
$$;
```

## Resources/sql/04_admin_usuarios.sql

```sql
SET search_path = academico, api, auth, public;
-- ============================================================
-- ADMINISTRACIÓN DE USUARIOS (CU-Administrador 02 a 07)
-- Todas las funciones de mutación validan a nivel de base de datos que
-- p_id_usuario_actor sea un ADMIN activo (defensa en profundidad: el backend
-- ya restringe estos endpoints con [Authorize(Roles = Admin)], pero la DB
-- no confía ciegamente en la capa de arriba).
-- ============================================================

-- ============================================================
-- TIPOS
-- ============================================================
DROP TYPE IF EXISTS api.usuario_admin CASCADE;
CREATE TYPE api.usuario_admin AS (
    id_usuario UUID,
    email CITEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    ultimo_login TIMESTAMPTZ,
    creado_en TIMESTAMPTZ,
    roles api.roles[],
    cantidad_sesiones BIGINT
);

-- ============================================================
-- CU 02 - Registrar usuarios (por un ADMIN)
-- Siempre nace con el rol PROFESOR_REGULAR. No emite sesión: el admin no
-- recibe tokens del usuario creado, solo su identidad.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_registrar_usuario_admin(-- TODO: ver nombre cambiar usuario_admin
    p_id_usuario_actor UUID,
    p_email CITEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_id UUID;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    IF p_email IS NULL OR trim(p_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF p_password_hash IS NULL OR trim(p_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    IF EXISTS (SELECT 1 FROM api.usuarios WHERE email = trim(p_email::TEXT)::CITEXT) THEN
        PERFORM auth.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash)
    VALUES (trim(p_email::TEXT)::CITEXT, p_password_hash)
    RETURNING id_usuario INTO v_id;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (v_id, 'PROFESOR_REGULAR', p_id_usuario_actor);

    RETURN v_id;
END;
$$;

-- ============================================================
-- CU 03 - Consultar usuarios (listado paginado + detalle)
-- Sin filtros (los aplica el frontend). p_pagina/p_tamano_pagina se
-- normalizan (clamp) en vez de lanzar error: la validación de rango real
-- ya la hace el DTO en C# con [Range].
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_listar_usuarios_admin(
    p_pagina INTEGER,
    p_tamano_pagina INTEGER
)
RETURNS SETOF api.usuario_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_pagina INTEGER := GREATEST(COALESCE(p_pagina, 1), 1);
    v_tamano INTEGER := LEAST(GREATEST(COALESCE(p_tamano_pagina, 20), 1), 100);
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.activo,
        u.bloqueado_hasta,
        u.ultimo_login,
        u.creado_en,
        COALESCE(array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::api.roles[]),
        COUNT(DISTINCT s.id_sesion)
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
    LEFT JOIN api.sesiones s ON s.id_usuario = u.id_usuario
    GROUP BY u.id_usuario, u.email, u.activo, u.bloqueado_hasta, u.ultimo_login, u.creado_en
    ORDER BY u.creado_en DESC
    LIMIT v_tamano
    OFFSET (v_pagina - 1) * v_tamano;
END;
$$;

-- Total de usuarios, para armar la metadata de paginación en el backend.
CREATE OR REPLACE FUNCTION auth.fn_contar_usuarios_admin()
RETURNS BIGINT
LANGUAGE sql
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*) FROM api.usuarios;
$$;

-- Detalle de un usuario puntual (sin password_hash).
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_admin_por_id(
    p_id_usuario UUID
)
RETURNS SETOF api.usuario_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.activo,
        u.bloqueado_hasta,
        u.ultimo_login,
        u.creado_en,
        COALESCE(array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::api.roles[]),
        COUNT(DISTINCT s.id_sesion)
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
    LEFT JOIN api.sesiones s ON s.id_usuario = u.id_usuario
    WHERE u.id_usuario = p_id_usuario
    GROUP BY u.id_usuario, u.email, u.activo, u.bloqueado_hasta, u.ultimo_login, u.creado_en;
END;
$$;

CREATE OR REPLACE PROCEDURE auth.sp_admin_resetear_contrasena(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_new_password_hash TEXT
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF p_new_password_hash IS NULL OR trim(p_new_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    UPDATE api.usuarios
    SET password_hash = p_new_password_hash,
        password_cambiada_en = NOW(),
        intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;
END;
$$;

-- ============================================================
-- CU 05 - Activar / desactivar usuarios
-- Reglas calcadas de auth.fn_revocar_rol: un admin no puede desactivarse a
-- sí mismo, y no se puede dejar el sistema sin ningún admin activo. Al
-- desactivar se revocan sesiones y se invalidan los access tokens ya
-- emitidos; al activar no se toca nada de eso.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_admin_cambiar_estado_usuario(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_activo BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_activo_actual BOOLEAN;
    v_tiene_admin BOOLEAN;
    v_cantidad_admins INTEGER;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    SELECT activo INTO v_activo_actual
    FROM api.usuarios
    WHERE id_usuario = p_id_usuario_objetivo;

    IF NOT FOUND THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF v_activo_actual = p_activo THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    IF p_activo = FALSE THEN
        IF p_id_usuario_actor = p_id_usuario_objetivo THEN
            PERFORM auth.fn_lanzar_excepcion('AU010', 'Un administrador no puede desactivarse a sí mismo.');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM api.usuario_roles
            WHERE id_usuario = p_id_usuario_objetivo AND rol = 'ADMIN'
        )
        INTO v_tiene_admin;

        IF v_tiene_admin THEN
            SELECT COUNT(*)
            INTO v_cantidad_admins
            FROM api.usuario_roles ur
            JOIN api.usuarios u ON u.id_usuario = ur.id_usuario
            WHERE ur.rol = 'ADMIN' AND u.activo = TRUE;

            IF v_cantidad_admins <= 1 THEN
                PERFORM auth.fn_lanzar_excepcion('AU011', 'No se puede desactivar al último administrador activo del sistema.');
            END IF;
        END IF;
    END IF;

    UPDATE api.usuarios
    SET activo = p_activo,
        actualizado_en = NOW(),
        tokens_invalidados_desde = CASE WHEN p_activo = FALSE THEN NOW() ELSE tokens_invalidados_desde END
    WHERE id_usuario = p_id_usuario_objetivo;

    IF p_activo = FALSE THEN
        DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;
    END IF;

    RETURN 'OK';
END;
$$;

-- CU 04 - Modificar email. Ahora devuelve también el email anterior (para auditoría).
DROP FUNCTION IF EXISTS auth.fn_admin_actualizar_email(UUID, UUID, CITEXT);
CREATE OR REPLACE FUNCTION auth.fn_admin_actualizar_email(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_nuevo_email CITEXT
)
RETURNS TABLE(out_status TEXT, out_email_anterior CITEXT)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_email_actual CITEXT;
    v_email_nuevo CITEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    SELECT email INTO v_email_actual
    FROM api.usuarios
    WHERE id_usuario = p_id_usuario_objetivo
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF p_nuevo_email IS NULL OR trim(p_nuevo_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    v_email_nuevo := trim(p_nuevo_email::TEXT)::CITEXT;

    IF EXISTS (
        SELECT 1 FROM api.usuarios
        WHERE email = v_email_nuevo
            AND id_usuario <> p_id_usuario_objetivo
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    IF v_email_actual = v_email_nuevo THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, v_email_actual;
        RETURN;
    END IF;

    UPDATE api.usuarios
    SET email = v_email_nuevo,
        tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;

    RETURN QUERY SELECT 'OK'::TEXT, v_email_actual;
END;
$$;

-- CU 07 - Eliminar usuario. Nuevo: bloquea si tiene perfil de profesor (PR003).
CREATE OR REPLACE FUNCTION auth.fn_admin_eliminar_usuario(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID
)
RETURNS TABLE(out_email CITEXT, out_roles api.roles[])
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_tiene_admin BOOLEAN;
    v_cantidad_admins INTEGER;
    v_email CITEXT;
    v_roles api.roles[];
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF p_id_usuario_actor = p_id_usuario_objetivo THEN
        PERFORM auth.fn_lanzar_excepcion('AU012', 'Un administrador no puede eliminarse a sí mismo.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.profesores WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('PR003', 'No se puede eliminar un usuario que tiene un perfil de profesor. Elimina primero el perfil.');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM api.usuario_roles
        WHERE id_usuario = p_id_usuario_objetivo AND rol = 'ADMIN'
    )
    INTO v_tiene_admin;

    IF v_tiene_admin THEN
        SELECT COUNT(*)
        INTO v_cantidad_admins
        FROM api.usuario_roles ur
        JOIN api.usuarios u ON u.id_usuario = ur.id_usuario
        WHERE ur.rol = 'ADMIN' AND u.activo = TRUE;

        IF v_cantidad_admins <= 1 THEN
            PERFORM auth.fn_lanzar_excepcion('AU013', 'No se puede eliminar al último administrador activo del sistema.');
        END IF;
    END IF;

    SELECT email INTO v_email FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo;

    SELECT COALESCE(array_agg(rol), ARRAY[]::api.roles[])
    INTO v_roles
    FROM api.usuario_roles
    WHERE id_usuario = p_id_usuario_objetivo;

    DELETE FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo;

    RETURN QUERY SELECT v_email, v_roles;
END;
$$;

-- ============================================================
-- CONSULTAS DE VERIFICACIÓN
-- ============================================================
SELECT * FROM auth.fn_listar_usuarios_admin(1, 20);
SELECT auth.fn_contar_usuarios_admin();
```

## Resources/sql/05_db.sql

```sql
SET search_path = academico, auth, public, pg_catalog;

-- ============================================================
-- ENUMS
-- ============================================================
BEGIN;
SET search_path = academico, pg_catalog;
DO $$
BEGIN
    CREATE TYPE academico.tipo_banda AS ENUM ('NUMERICA_1_7','LETRA_A_E','NUMERICA_0_100');
    CREATE TYPE academico.tipo_asignatura AS ENUM ('TRONCAL','SUPERIOR','MEDIO','MEP');
    CREATE TYPE academico.estado_monografia AS ENUM ('CAPACITACION','INVESTIGACION','TERMINADA');
    CREATE TYPE academico.estado_asistencia AS ENUM ('PRESENTE','AUSENTE','TARDIA','JUSTIFICADA');
    CREATE TYPE academico.tipo_reporte AS ENUM ('REPORTE_SECCION','REPORTE_ESTUDIANTE');
    CREATE TYPE academico.numero_semestre AS ENUM ('I_SEMESTRE','II_SEMESTRE');
    CREATE TYPE academico.estado_matricula AS ENUM ('EN_SISTEMA','ACTIVA','FINALIZADA');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- TABLAS
-- ============================================================

-- PROFESORES: perfil académico de un usuario (1 usuario -> 0..1 profesor)
CREATE TABLE IF NOT EXISTS academico.profesores (
    id_profesor BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20) NOT NULL,
    numero_celular VARCHAR(20),
    fecha_nacimiento DATE NOT NULL,
    id_usuario UUID NOT NULL,
    CONSTRAINT pk_profesores PRIMARY KEY (id_profesor),
    CONSTRAINT fk_profesores_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT uq_profesores_usuario UNIQUE (id_usuario),
    CONSTRAINT uq_profesores_cedula UNIQUE (cedula),
    CONSTRAINT ck_profesores_nombre CHECK (length(trim(nombre)) >= 2),
    CONSTRAINT ck_profesores_primer_apellido CHECK (length(trim(primer_apellido)) >= 2),
    CONSTRAINT ck_profesores_cedula CHECK (length(trim(cedula)) >= 5),
    CONSTRAINT ck_profesores_fecha_nacimiento CHECK (fecha_nacimiento BETWEEN DATE '1900-01-01' AND CURRENT_DATE)
);

-- ESTUDIANTES
CREATE TABLE IF NOT EXISTS academico.estudiantes (
    id_estudiante BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20) NOT NULL,
    numero_celular VARCHAR(20),
    email CITEXT NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_estudiantes PRIMARY KEY (id_estudiante),
    CONSTRAINT uq_estudiantes_cedula UNIQUE (cedula),
    CONSTRAINT uq_estudiantes_email UNIQUE (email),
    CONSTRAINT ck_estudiantes_nombre CHECK (length(trim(nombre)) >= 2),
    CONSTRAINT ck_estudiantes_primer_apellido CHECK (length(trim(primer_apellido)) >= 2),
    CONSTRAINT ck_estudiantes_cedula CHECK (length(trim(cedula)) >= 5),
    CONSTRAINT ck_estudiantes_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);
COMMIT;
```

## Resources/sql/06_admin_profesores.sql

```sql
SET search_path = academico, api, auth, public;

-- ============================================================
-- HELPER: valida que el actor sea ADMIN activo (AU009). Lo usan 06 y 07.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_validar_admin_activo(p_id_usuario_actor UUID)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;
END;
$$;

-- ============================================================
-- TIPOS
-- ============================================================
DROP TYPE IF EXISTS academico.profesor_admin CASCADE;
CREATE TYPE academico.profesor_admin AS (
    id_profesor BIGINT,
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20),
    numero_celular VARCHAR(20),
    fecha_nacimiento DATE,
    id_usuario UUID,
    email CITEXT
);

-- ============================================================
-- CU 08 - Registrar profesor (vincula un usuario existente)
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_registrar_profesor(
    p_id_usuario_actor UUID,
    p_id_usuario UUID,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_fecha_nacimiento DATE
)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_cedula TEXT := trim(p_cedula);
BEGIN
    PERFORM auth.fn_validar_admin_activo(p_id_usuario_actor);

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.profesores WHERE id_usuario = p_id_usuario) THEN
        PERFORM auth.fn_lanzar_excepcion('PR001', 'El usuario ya tiene un perfil de profesor.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.profesores WHERE cedula = v_cedula) THEN
        PERFORM auth.fn_lanzar_excepcion('PR002', 'Ya existe un profesor con esa cédula.');
    END IF;

    INSERT INTO academico.profesores (
        nombre, primer_apellido, segundo_apellido, cedula, numero_celular, fecha_nacimiento, id_usuario
    )
    VALUES (
        trim(p_nombre), trim(p_primer_apellido), NULLIF(trim(p_segundo_apellido), ''),
        v_cedula, NULLIF(trim(p_numero_celular), ''), p_fecha_nacimiento, p_id_usuario
    )
    RETURNING id_profesor INTO v_id;

    RETURN v_id;
END;
$$;

-- ============================================================
-- CU 09 - Consultar profesores (listado paginado + detalle)
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_listar_profesores_admin(
    p_pagina INTEGER,
    p_tamano_pagina INTEGER
)
RETURNS SETOF academico.profesor_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_pagina INTEGER := GREATEST(COALESCE(p_pagina, 1), 1);
    v_tamano INTEGER := LEAST(GREATEST(COALESCE(p_tamano_pagina, 20), 1), 100);
BEGIN
    RETURN QUERY
    SELECT p.id_profesor, p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula,
           p.numero_celular, p.fecha_nacimiento, p.id_usuario, u.email
    FROM academico.profesores p
    JOIN api.usuarios u ON u.id_usuario = p.id_usuario
    ORDER BY p.primer_apellido, p.segundo_apellido NULLS LAST, p.nombre, p.id_profesor
    LIMIT v_tamano
    OFFSET (v_pagina - 1) * v_tamano;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_contar_profesores_admin()
RETURNS BIGINT
LANGUAGE sql
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*) FROM academico.profesores;
$$;

CREATE OR REPLACE FUNCTION academico.fn_obtener_profesor_admin_por_id(p_id_profesor BIGINT)
RETURNS SETOF academico.profesor_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id_profesor, p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula,
           p.numero_celular, p.fecha_nacimiento, p.id_usuario, u.email
    FROM academico.profesores p
    JOIN api.usuarios u ON u.id_usuario = p.id_usuario
    WHERE p.id_profesor = p_id_profesor;
END;
$$;

-- ============================================================
-- CU 10 - Modificar profesor (todos los campos editables; el usuario vinculado NO cambia)
-- Devuelve el estado y el snapshot previo (JSONB) para auditoría.
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_admin_actualizar_profesor(
    p_id_usuario_actor UUID,
    p_id_profesor BIGINT,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_fecha_nacimiento DATE
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.profesores%ROWTYPE;
    v_nombre TEXT := trim(p_nombre);
    v_primer_apellido TEXT := trim(p_primer_apellido);
    v_segundo_apellido TEXT := NULLIF(trim(p_segundo_apellido), '');
    v_cedula TEXT := trim(p_cedula);
    v_celular TEXT := NULLIF(trim(p_numero_celular), '');
BEGIN
    PERFORM auth.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.profesores
    WHERE id_profesor = p_id_profesor
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM auth.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM academico.profesores
        WHERE cedula = v_cedula AND id_profesor <> p_id_profesor
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('PR002', 'Ya existe un profesor con esa cédula.');
    END IF;

    IF v_prev.nombre = v_nombre
        AND v_prev.primer_apellido = v_primer_apellido
        AND v_prev.segundo_apellido IS NOT DISTINCT FROM v_segundo_apellido
        AND v_prev.cedula = v_cedula
        AND v_prev.numero_celular IS NOT DISTINCT FROM v_celular
        AND v_prev.fecha_nacimiento = p_fecha_nacimiento
    THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    UPDATE academico.profesores
    SET nombre = v_nombre,
        primer_apellido = v_primer_apellido,
        segundo_apellido = v_segundo_apellido,
        cedula = v_cedula,
        numero_celular = v_celular,
        fecha_nacimiento = p_fecha_nacimiento
    WHERE id_profesor = p_id_profesor;

    RETURN QUERY SELECT 'OK'::TEXT, to_jsonb(v_prev);
END;
$$;

-- ============================================================
-- CU 11 - Eliminar profesor (solo el perfil; el usuario se conserva).
-- Si otras entidades lo referencian con FK RESTRICT, Postgres lanza 23503.
-- Devuelve el snapshot previo para auditoría.
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_profesor(
    p_id_usuario_actor UUID,
    p_id_profesor BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev JSONB;
BEGIN
    PERFORM auth.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT to_jsonb(p) INTO v_prev
    FROM academico.profesores p
    WHERE p.id_profesor = p_id_profesor
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM auth.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    DELETE FROM academico.profesores WHERE id_profesor = p_id_profesor;

    RETURN v_prev;
END;
$$;
```

## Resources/sql/07_admin_estudiantes.sql

```sql
SET search_path = academico, api, auth, public;

DROP TYPE IF EXISTS academico.estudiante_admin CASCADE;
CREATE TYPE academico.estudiante_admin AS (
    id_estudiante BIGINT,
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20),
    numero_celular VARCHAR(20),
    email CITEXT,
    fecha_nacimiento DATE,
    fecha_registro TIMESTAMPTZ
);

-- RN: entre 16 y 19 años (inclusive) al momento de inscribir o de cambiar la fecha de nacimiento.
CREATE OR REPLACE FUNCTION academico.fn_validar_edad_estudiante(p_fecha_nacimiento DATE)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF p_fecha_nacimiento IS NULL
        OR p_fecha_nacimiento NOT BETWEEN (CURRENT_DATE - INTERVAL '19 years')::DATE
                                      AND (CURRENT_DATE - INTERVAL '16 years')::DATE
    THEN
        PERFORM auth.fn_lanzar_excepcion('ES003', 'El estudiante debe tener entre 16 y 19 años.');
    END IF;
END;
$$;

-- ============================================================
-- CU 12 - Registrar estudiante
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_registrar_estudiante(
    p_id_usuario_actor UUID,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_email CITEXT,
    p_fecha_nacimiento DATE
)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_cedula TEXT := trim(p_cedula);
    v_email CITEXT := trim(p_email::TEXT)::CITEXT;
BEGIN
    PERFORM auth.fn_validar_admin_activo(p_id_usuario_actor);
    PERFORM academico.fn_validar_edad_estudiante(p_fecha_nacimiento);

    IF EXISTS (SELECT 1 FROM academico.estudiantes WHERE cedula = v_cedula) THEN
        PERFORM auth.fn_lanzar_excepcion('ES001', 'Ya existe un estudiante con esa cédula.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.estudiantes WHERE email = v_email) THEN
        PERFORM auth.fn_lanzar_excepcion('ES002', 'Ya existe un estudiante con ese correo.');
    END IF;

    INSERT INTO academico.estudiantes (
        nombre, primer_apellido, segundo_apellido, cedula, numero_celular, email, fecha_nacimiento
    )
    VALUES (
        trim(p_nombre), trim(p_primer_apellido), NULLIF(trim(p_segundo_apellido), ''),
        v_cedula, NULLIF(trim(p_numero_celular), ''), v_email, p_fecha_nacimiento
    )
    RETURNING id_estudiante INTO v_id;

    RETURN v_id;
END;
$$;

-- ============================================================
-- CU 13 - Consultar estudiantes
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_listar_estudiantes_admin(
    p_pagina INTEGER,
    p_tamano_pagina INTEGER
)
RETURNS SETOF academico.estudiante_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_pagina INTEGER := GREATEST(COALESCE(p_pagina, 1), 1);
    v_tamano INTEGER := LEAST(GREATEST(COALESCE(p_tamano_pagina, 20), 1), 100);
BEGIN
    RETURN QUERY
    SELECT e.id_estudiante, e.nombre, e.primer_apellido, e.segundo_apellido, e.cedula,
           e.numero_celular, e.email, e.fecha_nacimiento, e.fecha_registro
    FROM academico.estudiantes e
    ORDER BY e.primer_apellido, e.segundo_apellido NULLS LAST, e.nombre, e.id_estudiante
    LIMIT v_tamano
    OFFSET (v_pagina - 1) * v_tamano;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_contar_estudiantes_admin()
RETURNS BIGINT
LANGUAGE sql
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*) FROM academico.estudiantes;
$$;

CREATE OR REPLACE FUNCTION academico.fn_obtener_estudiante_admin_por_id(p_id_estudiante BIGINT)
RETURNS SETOF academico.estudiante_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT e.id_estudiante, e.nombre, e.primer_apellido, e.segundo_apellido, e.cedula,
           e.numero_celular, e.email, e.fecha_nacimiento, e.fecha_registro
    FROM academico.estudiantes e
    WHERE e.id_estudiante = p_id_estudiante;
END;
$$;

-- ============================================================
-- CU 14 - Modificar estudiante
-- La edad solo se revalida si cambia la fecha de nacimiento.
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_admin_actualizar_estudiante(
    p_id_usuario_actor UUID,
    p_id_estudiante BIGINT,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_email CITEXT,
    p_fecha_nacimiento DATE
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.estudiantes%ROWTYPE;
    v_nombre TEXT := trim(p_nombre);
    v_primer_apellido TEXT := trim(p_primer_apellido);
    v_segundo_apellido TEXT := NULLIF(trim(p_segundo_apellido), '');
    v_cedula TEXT := trim(p_cedula);
    v_celular TEXT := NULLIF(trim(p_numero_celular), '');
    v_email CITEXT := trim(p_email::TEXT)::CITEXT;
BEGIN
    PERFORM auth.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.estudiantes
    WHERE id_estudiante = p_id_estudiante
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM auth.fn_lanzar_excepcion('NF003', 'El estudiante no existe.');
    END IF;

    IF v_prev.fecha_nacimiento IS DISTINCT FROM p_fecha_nacimiento THEN
        PERFORM academico.fn_validar_edad_estudiante(p_fecha_nacimiento);
    END IF;

    IF EXISTS (
        SELECT 1 FROM academico.estudiantes
        WHERE cedula = v_cedula AND id_estudiante <> p_id_estudiante
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('ES001', 'Ya existe un estudiante con esa cédula.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM academico.estudiantes
        WHERE email = v_email AND id_estudiante <> p_id_estudiante
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('ES002', 'Ya existe un estudiante con ese correo.');
    END IF;

    IF v_prev.nombre = v_nombre
        AND v_prev.primer_apellido = v_primer_apellido
        AND v_prev.segundo_apellido IS NOT DISTINCT FROM v_segundo_apellido
        AND v_prev.cedula = v_cedula
        AND v_prev.numero_celular IS NOT DISTINCT FROM v_celular
        AND v_prev.email = v_email
        AND v_prev.fecha_nacimiento = p_fecha_nacimiento
    THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    UPDATE academico.estudiantes
    SET nombre = v_nombre,
        primer_apellido = v_primer_apellido,
        segundo_apellido = v_segundo_apellido,
        cedula = v_cedula,
        numero_celular = v_celular,
        email = v_email,
        fecha_nacimiento = p_fecha_nacimiento
    WHERE id_estudiante = p_id_estudiante;

    RETURN QUERY SELECT 'OK'::TEXT, to_jsonb(v_prev);
END;
$$;

-- ============================================================
-- CU 15 - Eliminar estudiante (borrado físico; devuelve snapshot para auditoría)
-- ============================================================
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_estudiante(
    p_id_usuario_actor UUID,
    p_id_estudiante BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev JSONB;
BEGIN
    PERFORM auth.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT to_jsonb(e) INTO v_prev
    FROM academico.estudiantes e
    WHERE e.id_estudiante = p_id_estudiante
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM auth.fn_lanzar_excepcion('NF003', 'El estudiante no existe.');
    END IF;

    DELETE FROM academico.estudiantes WHERE id_estudiante = p_id_estudiante;

    RETURN v_prev;
END;
$$;
```

## Resources/sql/views.sql

```sql
-- ============================================================
-- VIEWS
-- ============================================================

-- Usuarios con sus roles y numero de sesiones
CREATE OR REPLACE VIEW api.vw_usuarios AS
SELECT
    u.id_usuario,
    u.email,
    u.activo,
    u.bloqueado_hasta,
    COALESCE(array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::api.roles[]) AS roles,
    COUNT(s.id_sesion) AS cantidad_sesiones
FROM api.usuarios u
LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
LEFT JOIN api.sesiones s ON s.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.email, u.activo, u.bloqueado_hasta;

-- Ver los logs y usuarios relacionados
CREATE OR REPLACE VIEW api.vw_logs AS
SELECT 
    l.id_log, l.id_usuario, u.email, l.accion, 
    l.tabla_afectada, l.id_registro_afectado,
    l.datos_anteriores, l.datos_nuevos, l.direccion_ip, l.agente_usuario,
    l.creado_en
FROM api.logs l
LEFT JOIN api.usuarios u ON l.id_usuario = u.id_usuario
ORDER BY l.creado_en DESC;

-- Sesiones con sus usuarios
CREATE OR REPLACE VIEW api.vw_sesiones AS
SELECT s.id_usuario, u.email, s.creado_en, s.expira_en, s.rotado_en, s.direccion_ip, s.agente_usuario
FROM api.sesiones s
JOIN api.usuarios u ON u.id_usuario = s.id_usuario
ORDER BY s.creado_en DESC;

SELECT * FROM api.vw_usuarios;
SELECT * FROM api.vw_logs;
SELECT * FROM api.vw_sesiones;
```
# Project Structure

```
└── Program.cs
```

# File Contents

## Program.cs

```csharp
using iet_bi_portal_backend.Modules.Auth;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Users;
using iet_bi_portal_backend.Modules.Professors;
using iet_bi_portal_backend.Modules.Students;
using iet_bi_portal_backend.Config;
using DotNetEnv;

Env.Load();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddDatabase(builder.Configuration);

builder.Services.AddAuthModule(builder.Configuration);
builder.Services.AddLogsModule();
builder.Services.AddErrorsModule();
builder.Services.AddUsersModule();
builder.Services.AddProfessorsModule();
builder.Services.AddStudentsModule();

var app = builder.Build();

app.UseExceptionHandler();

if (!app.Environment.IsDevelopment())
    app.UseHsts();

app.UseHttpsRedirection();
app.UseAuthModule();
app.MapControllers();
app.Run();
```



