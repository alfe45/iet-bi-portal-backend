using Npgsql;
using iet_bi_portal_backend;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
var connectionString = builder.Configuration.GetConnectionString("PortalDatabase")
    ?? throw new InvalidOperationException("No existe la cadena de conexión PortalDatabase.");
builder.Services.AddSingleton(NpgsqlDataSource.Create(connectionString));
builder.Services.AddScoped<ProfesoresService>();
builder.Services.AddScoped<EstudiantesService>();
builder.Services.AddScoped<MatriculasService>();
builder.Services.AddScoped<SeccionesService>();
builder.Services.AddScoped<CursosLectivosService>();
builder.Services.AddCors(options => options.AddPolicy("Frontend", policy => policy
    .AllowAnyHeader()
    .AllowAnyMethod()
    .AllowAnyOrigin()));
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors("Frontend");
app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
