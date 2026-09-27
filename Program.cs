using iet_bi_portal_backend.Modules.Auth;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Errors;
using iet_bi_portal_backend.Modules.Users;
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

var app = builder.Build();

app.UseExceptionHandler();

if (!app.Environment.IsDevelopment())
    app.UseHsts();

app.UseHttpsRedirection();
app.UseAuthModule();
app.MapControllers();
app.Run();