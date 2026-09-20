namespace iet_bi_portal_backend.Models;

// Datos que recibe el endpoint para registrar un profesor.
public sealed record RegistrarProfesorRequest(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento,
    string Password);

// Datos que recibe el endpoint para actualizar un profesor.
public sealed record ActualizarProfesorRequest(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento,
    string Password);

// Datos que devuelve la API para mostrar un profesor.
public sealed record ProfesorResponse(
    long IdProfesor,
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento,
    DateTime FechaRegistro,
    bool Activo);
