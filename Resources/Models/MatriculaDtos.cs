namespace iet_bi_portal_backend.Models;

// Datos necesarios para matricular un estudiante en nivel 10.
public sealed record RegistrarMatriculaNivel10Request(string CedulaEstudiante, int? YearCiclo, int? NumeroSeccion);

// Datos que devuelve la API para mostrar el historial de matrícula.
public sealed record MatriculaResponse(
    long IdMatricula,
    int YearCiclo,
    long IdSeccion,
    string Seccion,
    DateTimeOffset FechaMatricula,
    string Estado,
    DateTimeOffset? FechaFinalizacion);
