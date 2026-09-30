namespace iet_bi_portal_backend.Common.Models;

/// <summary>Patrones de validación compartidos. Deben coincidir con los CHECK de la base de datos.</summary>
public static class PatronesValidacion
{
    /// <summary>RN-11: 5 a 20 caracteres; letras, dígitos o guion.</summary>
    public const string Cedula = "^[A-Za-z0-9-]{5,20}$";
    public const string MensajeCedula = "La cédula debe tener entre 5 y 20 caracteres (letras, dígitos o guion).";
}
