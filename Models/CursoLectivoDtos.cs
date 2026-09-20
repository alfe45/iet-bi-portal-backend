namespace iet_bi_portal_backend.Models;

// Datos que devuelve la API para mostrar un curso lectivo.
public sealed record CursoLectivoResponse(long IdCursoLectivo, int YearCiclo, DateOnly FechaInicio, DateOnly FechaFin);

// Datos necesarios para abrir o actualizar un curso y sus semestres.
public sealed record CursoLectivoRequest(int? YearCiclo, DateOnly? FechaInicioI, DateOnly? FechaFinI, DateOnly? FechaInicioII, DateOnly? FechaFinII);
