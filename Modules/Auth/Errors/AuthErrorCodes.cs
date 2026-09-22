namespace iet_bi_portal_backend.Modules.Auth.Errors;

/// <summary>
/// Códigos de error del módulo Auth. Coinciden 1 a 1 con el ERRCODE que lanza
/// auth.fn_lanzar_excepcion() en la base de datos — nunca se identifica un
/// error por el texto del mensaje (frágil, depende del idioma/redacción).
/// </summary>
public static class AuthErrorCodes
{
    public const string RoleForbidden = "AP001";
    public const string UserNotFound = "AP002";
    public const string CannotRemoveLastRole = "AP003";
    public const string BootstrapAlreadyDone = "AP004";
    public const string EmailTaken = "AP005";
    public const string CannotRemoveProfessorRole = "AP006";
}