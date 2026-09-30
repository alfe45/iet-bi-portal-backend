using DotNetEnv;
using iet_bi_portal_backend.Common;
using iet_bi_portal_backend.Config;
using iet_bi_portal_backend.Modules.Asignaciones;
using iet_bi_portal_backend.Modules.Asignaturas;
using iet_bi_portal_backend.Modules.Ausentismo;
using iet_bi_portal_backend.Modules.Auth;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Estudiantes;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Matriculas;
using iet_bi_portal_backend.Modules.Periodos;
using iet_bi_portal_backend.Modules.Profesores;
using iet_bi_portal_backend.Modules.Secciones;
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
builder.Services.AddPeriodosModule();
builder.Services.AddSeccionesModule();
builder.Services.AddAsignaturasModule();
builder.Services.AddAsignacionesModule();
builder.Services.AddMatriculasModule();
builder.Services.AddAusentismoModule();

var app = builder.Build();

app.UseExceptionHandler();

// En desarrollo el perfil "http" no tiene puerto HTTPS: redirigir solo fuera de Development.
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}
app.UseAuthModule();
app.MapControllers();
app.Run();

