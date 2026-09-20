namespace iet_bi_portal_backend.Models;

// Datos que devuelve la API para mostrar una sección.
public sealed record SeccionResponse(long IdSeccion, int YearCiclo, string Seccion);

// Datos necesarios para registrar una sección.
public sealed record RegistrarSeccionRequest(int? YearCiclo, int? Nivel, int? NumeroSeccion);
