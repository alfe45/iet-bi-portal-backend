namespace iet_bi_portal_backend.Models;

// Datos que recibe el endpoint para registrar un estudiante.
public sealed record RegistrarEstudianteRequest(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento);

// Datos que recibe el endpoint para actualizar un estudiante.
public sealed record ActualizarEstudianteRequest(
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento);

// Datos que devuelve la API para mostrar un estudiante.
public sealed record EstudianteResponse(
    long IdEstudiante,
    string Nombre,
    string PrimerApellido,
    string? SegundoApellido,
    string Cedula,
    string? NumeroCelular,
    string Email,
    DateOnly FechaNacimiento,
    DateTime FechaRegistro);
