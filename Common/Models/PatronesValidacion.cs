namespace iet_bi_portal_backend.Common.Models;

/// <summary>Patrones de validación compartidos. Deben coincidir con los CHECK de la base de datos.</summary>
public static class PatronesValidacion
{
    /// <summary>RN-11: 5 a 20 caracteres; letras, dígitos o guion.</summary>
    public const string Cedula = "^[A-Za-z0-9-]{5,20}$";
    public const string MensajeCedula = "La cédula debe tener entre 5 y 20 caracteres (letras, dígitos o guion).";
}

/// <summary>Valores del enum academico.numero_semestre (deben coincidir con la DB). Lo usan ausentismo, evaluaciones,
/// monografías, CAS e informes.</summary>
public static class Semestres
{
    public const string Patron = "(?i)^(I_SEMESTRE|II_SEMESTRE)$";   // sin distinguir mayúsculas
    public const string Mensaje = "El semestre debe ser I_SEMESTRE o II_SEMESTRE.";

    /// <summary>Normaliza a mayúsculas para el cast ::academico.numero_semestre (RP-52).</summary>
    public static string? Normalizar(string? semestre) => semestre?.Trim().ToUpperInvariant();
}
