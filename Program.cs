using DotNetEnv;
using iet_bi_portal_backend.Common;
using iet_bi_portal_backend.Config;
using iet_bi_portal_backend.Modules.Auth;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Estudiantes;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Profesores;
using iet_bi_portal_backend.Modules.Usuarios;

Env.Load();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
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

var app = builder.Build();

app.UseExceptionHandler();

if (!app.Environment.IsDevelopment())
    app.UseHsts();

app.UseHttpsRedirection();
app.UseAuthModule();
app.MapControllers();
app.Run();

