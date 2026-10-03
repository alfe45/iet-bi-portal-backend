using DotNetEnv;
using iet_bi_portal_backend.Common;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Config;
using iet_bi_portal_backend.Modules.Asignaciones;
using iet_bi_portal_backend.Modules.Asignaturas;
using iet_bi_portal_backend.Modules.Ausentismo;
using iet_bi_portal_backend.Modules.Cas;
using iet_bi_portal_backend.Modules.Evaluaciones;
using iet_bi_portal_backend.Modules.Informes;
using iet_bi_portal_backend.Modules.Monografias;
using iet_bi_portal_backend.Modules.Auth;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Estudiantes;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Matriculas;
using iet_bi_portal_backend.Modules.Periodos;
using iet_bi_portal_backend.Modules.Profesores;
using iet_bi_portal_backend.Modules.Secciones;
using iet_bi_portal_backend.Modules.Usuarios;
using Microsoft.AspNetCore.HttpOverrides;
using Npgsql;

// ENV_FILE elige el archivo de variables (lo fijan los perfiles de launchSettings.json); sin ella, .env.
Env.Load(Environment.GetEnvironmentVariable("ENV_FILE") ?? ".env");

var builder = WebApplication.CreateBuilder(args);

// Sin cabecera Server y cuerpo máximo de 1 MB (el mayor pedido legítimo, 100 notas o 30 experiencias CAS, ocupa pocos KB).
builder.WebHost.ConfigureKestrel(o =>
{
    o.AddServerHeader = false;
    o.Limits.MaxRequestBodySize = 1024 * 1024;
});

// Toda petición que modifica datos va en una transacción: operación y auditoría juntas (RP-58).
builder.Services.AddControllers(o => o.Filters.Add<TransaccionPorPeticionFilter>());
// CORS_ORIGINS: orígenes del frontend separados por comas (en Render, la URL pública del frontend); sin ella, el Angular local.
var origenesCors = (builder.Configuration["CORS_ORIGINS"] ?? "http://localhost:4200,http://127.0.0.1:4200")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
builder.Services.AddCors(o => o.AddPolicy("frontend", policy => policy
    .WithOrigins(origenesCors)
    .AllowAnyHeader()
    .AllowAnyMethod()));

// CONFIAR_PROXY=true solo detrás de un proxy inverso (Render): toma la IP real del cliente y el esquema de
// X-Forwarded-For/Proto. Sin esto el rate limiting de /auth agrupa a todos los usuarios bajo la IP del proxy.
// No activarlo si la API es accesible directamente: un cliente podría falsificar su IP con la cabecera.
var confiarProxy = string.Equals(builder.Configuration["CONFIAR_PROXY"], "true", StringComparison.OrdinalIgnoreCase);
if (confiarProxy)
{
    builder.Services.Configure<ForwardedHeadersOptions>(o =>
    {
        o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        o.KnownIPNetworks.Clear();
        o.KnownProxies.Clear();
    });
}
builder.Services.AddDatabase(builder.Configuration);
builder.Services.AddCommon();

// Infraestructura compartida
builder.Services.AddErrorsModule();
builder.Services.AddLogsModule();

// Módulos de negocio (no dependen entre sí: RP-40)
builder.Services.AddAuthModule(builder.Configuration);
builder.Services.AddUsuariosModule();
builder.Services.AddProfesoresModule();
builder.Services.AddEstudiantesModule();
builder.Services.AddPeriodosModule();
builder.Services.AddSeccionesModule();
builder.Services.AddAsignaturasModule();
builder.Services.AddAsignacionesModule();
builder.Services.AddMatriculasModule();
builder.Services.AddAusentismoModule();
builder.Services.AddEvaluacionesModule();
builder.Services.AddMonografiasModule();
builder.Services.AddCasModule();
builder.Services.AddInformesModule();

var app = builder.Build();

// Mínimo privilegio: la API no debería conectarse como superusuario de PostgreSQL (hallazgo H-09).
try
{
    await using var cmd = app.Services.GetRequiredService<NpgsqlDataSource>()
        .CreateCommand("SELECT rolsuper FROM pg_roles WHERE rolname = current_user");
    if (await cmd.ExecuteScalarAsync() is true)
        app.Logger.LogWarning("La API está conectada a PostgreSQL con un superusuario. En producción usa un rol con permisos mínimos (svc_api, ver 01_roles_schemas.sql).");
}
catch (Exception ex)
{
    app.Logger.LogWarning(ex, "No se pudo verificar los privilegios del usuario de base de datos.");
}

if (confiarProxy)
    app.UseForwardedHeaders();
app.UseExceptionHandler();
app.UseCors("frontend");

// Cabeceras de seguridad: las respuestas traen datos personales (Ley 8968): no se guardan en caché ni se reinterpretan.
// OnStarting: se aplican justo antes de enviar, también en las respuestas de error (UseExceptionHandler limpia las
// cabeceras ya puestas al manejar una excepción).
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        context.Response.Headers.XContentTypeOptions = "nosniff";
        context.Response.Headers.CacheControl = "no-store";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        return Task.CompletedTask;
    });
    await next();
});

// En desarrollo el perfil "http" no tiene puerto HTTPS: redirigir solo fuera de Development.
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}
app.UseAuthModule();
app.MapControllers();
app.Run();
